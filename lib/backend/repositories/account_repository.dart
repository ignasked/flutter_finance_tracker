import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncService
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
import 'package:uuid/uuid.dart'; // Make sure you have this import and the package in pubspec.yaml

class AccountRepository extends BaseRepository<Account> {
  final AuthService _authService;
  SyncService? syncService; // <-- Make public and nullable

  // Modify constructor to accept nullable SyncService
  AccountRepository(Store store, this._authService, this.syncService)
      : super(store);

  Future<void> init() async {
    // Ensure Defaults are loaded before repository uses them, especially for defaultCurrency
    await Defaults().loadDefaults();
    await _initializeDefaultAccounts(); // Keep initialization
    await _setDefaultAccount(); // Add call to set default instance separately
  }

  Future<void> _setDefaultAccount() async {
    // Use getById which respects user context and deleted status
    if (Defaults().defaultAccountId != null) {
      final defaultAcc = await getById(Defaults().defaultAccountId!);
      if (defaultAcc != null) {
        Defaults().setDefaultAccountInstance(defaultAcc);
        return; // Already set and instance loaded
      } else {
        // ID was saved but account not found (e.g., deleted), proceed to fallback
        print(
            "Warning: Default account ID ${Defaults().defaultAccountId} found in prefs, but account not found in DB. Resetting default.");
      }
    }

    // Fallback logic if default ID isn't set or account wasn't found
    final userCondition = _userIdCondition();
    final anyAccQuery =
        box.query(userCondition.and(_notDeletedCondition())).build();
    final fallbackAcc = await anyAccQuery.findFirstAsync();
    anyAccQuery.close();
    if (fallbackAcc != null) {
      Defaults().setDefaultAccountInstance(fallbackAcc);
      await Defaults().saveDefaults(); // Save the new fallback default ID
      print("Set fallback default account: ${fallbackAcc.name}");
    } else {
      print("Error: No account available to set as default.");
      // Handle case where no accounts exist at all if necessary
    }
  }

  /// Factory method for asynchronous initialization
  static Future<AccountRepository> create(
      Store store, AuthService authService, SyncService syncService) async {
    // Ensure Defaults are loaded before repository uses them
    await Defaults().loadDefaults();
    return AccountRepository(store, authService, syncService);
  }

  /// Initializes default accounts if they don't exist (based on UUID)
  /// Does NOT set the default instance in the Defaults singleton.
  Future<void> _initializeDefaultAccounts() async {
    final userCondition = _userIdCondition();
    final notDeleted = _notDeletedCondition();

    // 1. Check if the user already has ANY accounts.
    final existingAccountsQuery =
        box.query(userCondition.and(notDeleted)).build();
    final bool userHasAccounts = existingAccountsQuery.count() > 0;
    existingAccountsQuery.close();

    if (userHasAccounts) {
      print(
          "User already has accounts. Skipping default account initialization.");
      return;
    }

    // 2. If user has no accounts, initialize all defaults with new UUIDs
    print("User has no accounts. Initializing defaults with unique UUIDs...");

    final List<Account> accountsToAdd = [];
    final Uuid uuidGenerator = Uuid(); // Create a Uuid instance

    // Ensure Defaults are loaded so defaultCurrency is available
    await Defaults().loadDefaults();

    for (final template in Defaults().defaultAccountsData) {
      accountsToAdd.add(
        Account(
          uuid: uuidGenerator
              .v4(), // Generate a NEW, UNIQUE UUID for this instance
          name: template.name,
          typeValue: template.typeValue,
          currency: Defaults().defaultCurrency, // Use current default currency
          currencySymbol:
              Defaults().defaultCurrencySymbol, // Use current default symbol
          balance: template.balance,
          colorValue: template.colorValue,
          iconCodePoint: template.iconCodePoint,
          isEnabled: template.isEnabled,
        ),
      );
    }

    if (accountsToAdd.isNotEmpty) {
      try {
        // putMany will assign userId, createdAt, updatedAt
        await putMany(accountsToAdd, syncSource: SyncSource.local);
        print(
            'Added ${accountsToAdd.length} default accounts in batch with unique UUIDs.');
      } catch (e) {
        print('Error adding default accounts in batch: $e');
      }
    } else {
      print("Default accounts data is empty. Nothing to add.");
    }
  }

  /// Helper to ensure non-primary default accounts exist.
  Future<void> _ensureOtherDefaultAccountsExist(
      Condition<Account> userCondition) async {
    print(
        "Reviewing _ensureOtherDefaultAccountsExist: This method needs refactoring to use unique UUIDs and check by name or other user-specific unique properties.");
  }

  Condition<Account> _userIdCondition() {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null
        ? Account_.userId.equals(currentUserId)
        : Account_.userId.isNull();
  }

  Condition<Account> _notDeletedCondition() {
    return Account_.deletedAt.isNull();
  }

  Condition<Transaction> _transactionUserIdCondition() {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null
        ? Transaction_.userId.equals(currentUserId)
        : Transaction_.userId.isNull();
  }

  Future<bool> _hasTransactionsForAccount(int accountId) async {
    final transactionBox = store.box<Transaction>();
    final query = transactionBox
        .query((Transaction_.fromAccount
                .equals(accountId)
                .or(Transaction_.toAccount.equals(accountId)))
            .and(Transaction_.deletedAt.isNull())
            .and(_transactionUserIdCondition()))
        .build();
    final count = query.count();
    query.close();
    return count > 0;
  }

  /// Fetch only enabled (and not soft-deleted) accounts for the current context.
  Future<List<Account>> getEnabledAccounts() async {
    try {
      final query = box
          .query(Account_.isEnabled
              .equals(true)
              .and(_userIdCondition())
              .and(_notDeletedCondition())) // Exclude deleted
          .build();
      final enabledAccounts = await query.findAsync();
      query.close();
      return enabledAccounts;
    } catch (e) {
      print('Error fetching enabled accounts asynchronously: $e');
      return [];
    }
  }

  /// Get accounts modified after a specific time (UTC) for the current context.
  /// Includes soft-deleted items as they might need syncing.
  Future<List<Account>> getAllModifiedSince(DateTime time) async {
    final query = box
        .query(Account_.updatedAt
            .greaterThan(time.toUtc().millisecondsSinceEpoch)
            .and(_userIdCondition())) // Filter by user
        .build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Fetch all non-deleted accounts for the current context.
  @override
  Future<List<Account>> getAll() async {
    try {
      final query = box
          .query(_userIdCondition()
              .and(_notDeletedCondition())) // Filter by user and not deleted
          .build();
      final results = await query.findAsync();
      query.close();

      _setDefaultAccount(); // Set default account instance after fetching all accounts

      return results;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print('Error fetching accounts for context $context: $e');
      return [];
    }
  }

  /// Fetch an account by ID if it belongs to the current context and is not soft-deleted.
  @override
  Future<Account?> getById(int id) async {
    try {
      final query = box
          .query(Account_.id
              .equals(id)
              .and(_userIdCondition())
              .and(_notDeletedCondition())) // Filter by user and not deleted
          .build();
      final result = await query.findFirstAsync();
      query.close();
      return result;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print("Error fetching account $id for context $context: $e");
      return null;
    }
  }

  /// Fetch multiple accounts by their IDs for the current context.
  /// Optionally includes soft-deleted items.
  Future<List<Account>> getManyByIds(List<int> ids,
      {bool includeDeleted = false}) async {
    // Added includeDeleted parameter
    if (ids.isEmpty) return [];
    // Remove duplicates and 0 if present
    final uniqueIds = ids.where((id) => id != 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    try {
      // Base condition: match IDs and user context
      Condition<Account> condition =
          Account_.id.oneOf(uniqueIds) & _userIdCondition();

      // Conditionally add the 'notDeleted' filter
      if (!includeDeleted) {
        condition = condition & _notDeletedCondition();
      }

      final query = box.query(condition).build();
      final results = await query.findAsync();
      query.close();
      return results;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print('Error fetching multiple accounts for context $context: $e');
      return [];
    }
  }

  /// Soft removes an account by ID if it belongs to the current context,
  /// is not a default account, and has no transactions.
  @override
  Future<bool> remove(int id) async {
    final currentUserId = _authService.currentUser?.id;
    // Prevent deletion of default accounts (assuming IDs 1 and 2)
    if (id == 1 || id == 2) {
      print("Error: Cannot delete default account ID $id.");
      return false;
    }

    // Check for transactions
    final hasTransactions = await _hasTransactionsForAccount(id);
    if (hasTransactions) {
      print("Error: Cannot delete account ID $id, it has transactions.");
      return false;
    }

    try {
      // Fetch the item, ensuring it belongs to the user and is not deleted
      final query = box
          .query(Account_.id
              .equals(id)
              .and(_userIdCondition())
              .and(_notDeletedCondition()))
          .build();
      final item = await query.findFirstAsync();
      query.close();

      if (item == null) {
        print(
            "Soft remove failed: Account $id not found, doesn't belong to user $currentUserId, or already deleted.");
        return false;
      }

      // Prepare the update for soft delete
      final now = DateTime.now();
      final nowUtc = now.toUtc();
      final itemToUpdate = item.copyWith(
        deletedAt: nowUtc,
        updatedAt: now, // Also update 'updatedAt' for sync mechanisms
      );

      // --- ADD: Push delete immediately (Fire-and-Forget) ---
      if (syncService != null) {
        print("Pushing soft delete for Account ID $id (no await).");
        syncService!
            .pushSingleUpsert<Account>(itemToUpdate)
            .catchError((pushError) {
          print(
              "Background push error during remove for Account ID $id: $pushError");
        });
      } else {
        print(
            "Warning: syncService is null in AccountRepository.remove. Cannot push delete immediately.");
      }
      // --- END ADD ---

      // Perform the local update using box directly
      await box.putAsync(itemToUpdate);
      print("Soft removed Account $id locally.");
      return true;
    } catch (e, stacktrace) {
      print("Error during soft remove for Account ID $id: $e");
      print(stacktrace);
      return false;
    }
  }

  /// Restores a soft-deleted account by ID if it belongs to the current context.
  Future<bool> restoreAccount(int id) async {
    return await super.restore(id);
  }

  /// Updates accounts with null userId to the provided newUserId.
  /// Skips accounts that are soft-deleted.
  Future<int> assignUserIdToNullEntries(String newUserId) async {
    final query = box
        .query(Account_.userId
            .isNull()
            .and(_notDeletedCondition())) // Only assign to non-deleted
        .build();
    final nullUserItems = await query.findAsync();
    query.close();

    if (nullUserItems.isEmpty) {
      return 0;
    }

    print(
        "Assigning userId $newUserId to ${nullUserItems.length} local-only accounts...");

    final List<Account> updatedItems = [];
    final now = DateTime.now();

    for (final item in nullUserItems) {
      // Check if an account with the same UUID already exists for the target user
      final existingUserItemQuery = box
          .query(Account_.uuid // Use UUID for matching
              .equals(item.uuid)
              .and(Account_.userId.equals(newUserId)))
          .build();
      final existingUserItem = await existingUserItemQuery.findFirstAsync();
      existingUserItemQuery.close();

      if (existingUserItem != null) {
        print(
            "Skipping assignment for account UUID ${item.uuid}: Already exists for user $newUserId with ID ${existingUserItem.id}. Consider merging or deleting local item ID ${item.id}.");
        continue;
      }
      updatedItems.add(item.copyWith(
        userId: newUserId,
        updatedAt: now,
      ));
    }

    if (updatedItems.isNotEmpty) {
      await putMany(updatedItems, syncSource: SyncSource.local);
      print(
          "Successfully assigned userId $newUserId to ${updatedItems.length} accounts.");
      return updatedItems.length;
    } else {
      print(
          "No accounts needed userId assignment after checking for existing entries by UUID.");
      return 0;
    }
  }

  /// Soft deletes all accounts for the currently logged-in user.
  /// If no user is logged in, soft deletes accounts with a null userId.
  Future<int> removeNonDefaultForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;

    // Define the base condition based on user authentication state
    final Condition<Account> userCondition = currentUserId != null
        ? Account_.userId.equals(currentUserId)
        : Account_.userId.isNull();

    // Define common conditions
    final Condition<Account> notDeletedCondition = Account_.deletedAt.isNull();

    final Condition<Account> notDefaultCondition =
        Account_.id.greaterThan(Defaults().defaultAccountsData.length);

    // Combine all conditions using the '&' operator
    final Condition<Account> finalCondition =
        userCondition & notDeletedCondition & notDefaultCondition;

    // Build the query with the combined condition
    final query = box.query(finalCondition).build(); // Build the Query object

    final accountsToDelete = await query.findAsync(); // Find using the Query
    query.close(); // Close the Query object after finding

    if (accountsToDelete.isEmpty) {
      print(
          "No accounts found to delete for user: ${currentUserId ?? 'unauthenticated'}");
      return 0;
    }

    int successCount = 0;
    int skippedCount = 0;
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    final List<Account> itemsToSoftDelete = []; // Collect items

    for (final item in accountsToDelete) {
      final hasTransactions = await _hasTransactionsForAccount(item.id);
      if (hasTransactions) {
        print("Skipping delete for Account ID ${item.id}: Has transactions.");
        skippedCount++;
        continue;
      }
      itemsToSoftDelete.add(item.copyWith(
        // Add to list
        deletedAt: nowUtc,
        updatedAt: now,
      ));
    }

    // --- MODIFIED: Push deletes using pushUpsertMany (Fire-and-Forget) ---
    if (syncService != null && itemsToSoftDelete.isNotEmpty) {
      print(
          "Pushing ${itemsToSoftDelete.length} account deletes using pushUpsertMany (no await).");
      syncService!
          .pushUpsertMany<Account>(itemsToSoftDelete)
          .catchError((pushError) {
        print(
            "Background push error during pushUpsertMany for deleting Accounts: $pushError");
      });
    } else if (syncService == null) {
      print(
          "Warning: syncService is null in removeNonDefaultForCurrentUser (Account). Cannot push deletes immediately.");
    }
    // --- END MODIFIED ---

    // Perform local batch update
    if (itemsToSoftDelete.isNotEmpty) {
      try {
        await box.putManyAsync(itemsToSoftDelete);
        successCount = itemsToSoftDelete.length;
      } catch (e) {
        print(
            "Error during local putManyAsync in removeNonDefaultForCurrentUser (Account): $e");
      }
    }

    print(
        "Attempted soft remove for $successCount non-default accounts (ID > 2) for user ${_authService.currentUser?.id ?? 'unauthenticated'}.${skippedCount > 0 ? " Skipped $skippedCount." : ""}");
    return successCount;
  }

  /// Override removeAll from BaseRepository to prevent accidental hard deletion.
  @override
  Future<int> removeAll() async {
    print(
        "Error: Direct call to removeAll() is disabled for safety. Use removeAllForCurrentUser() for soft deletion instead.");
    throw UnimplementedError(
        "Use removeAllForCurrentUser() to soft-delete user-specific data.");
  }

  /// Override put to update timestamps, set userId, and push changes.
  @override
  Future<int> put(Account account,
      {SyncSource syncSource = SyncSource.local}) async {
    final currentUserId = _authService.currentUser?.id;
    int resultId = account.id; // Initialize with incoming ID

    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Account accountToSave;

      if (account.id == 0) {
        // New account
        accountToSave = account.copyWith(
          userId: currentUserId,
          createdAt: now,
          updatedAt: now,
          // Ensure deletedAt is null for new items unless explicitly set
          deletedAt: account.deletedAt,
        );
      } else {
        // Existing account
        // Use box.get directly to fetch even if soft-deleted, needed for updates/restores
        final existing = await box.getAsync(account.id);
        if (existing == null) {
          print(
              "Warning: Attempted to update non-existent account ID: ${account.id}");
          // Decide if you want to insert it as new or throw error
          // For now, let's prevent accidental creation on update failure
          return account.id; // Or throw?
        }
        // Check context
        if (existing.userId != currentUserId) {
          // Allow update only if the existing userId is null (assignment case)
          if (existing.userId != null) {
            print(
                "Error: Attempted to update account with mismatched userId context. Existing: ${existing.userId}, Current: $currentUserId");
            throw Exception(
                "Cannot modify data belonging to a different user context.");
          }
          print(
              "Info: Assigning userId $currentUserId to account ID ${account.id}");
        }

        accountToSave = account.copyWith(
          userId: currentUserId, // Ensure context is set/updated
          updatedAt: now, // Always update timestamp
          createdAt: account.createdAt != DateTime.fromMillisecondsSinceEpoch(0)
              ? account.createdAt
              : existing.createdAt, // Preserve original createdAt
          // copyWith handles deletedAt logic (including setDeletedAtNull)
        );
      }

      if (accountToSave.userId != currentUserId) {
        print(
            "Error: Mismatched userId (${accountToSave.userId}) during save for current context ($currentUserId).");
        throw Exception("Data integrity error: User ID mismatch.");
      }

      // Use super.put to save locally
      resultId = await super.put(accountToSave, syncSource: syncSource);

      // --- Push Change Immediately (Fire-and-Forget) ---
      if (resultId != 0 && syncService != null) {
        final savedItem = await box.getAsync(resultId);
        if (savedItem != null) {
          print(
              "Pushing change for Account ID $resultId immediately after local put (no await).");
          syncService!
              .pushSingleUpsert<Account>(savedItem)
              .catchError((pushError) {
            print("Background push error for Account ID $resultId: $pushError");
          });
        } else {
          print(
              "Warning: Could not fetch Account ID $resultId after put for immediate push.");
        }
      } else if (syncService == null) {
        print(
            "Warning: syncService is null in AccountRepository.put. Cannot push change immediately.");
      }
      // --- End Push Change ---

      return resultId;
    } else {
      // Syncing down from Supabase
      if (account.userId == null) {
        print(
            "Warning: Syncing down account with null userId. ID: ${account.id}");
      }
      final accountToSave = account.copyWith(
          createdAt: account.createdAt.toLocal(),
          updatedAt: account.updatedAt.toLocal(),
          deletedAt: account.deletedAt?.toLocal()); // Ensure deletedAt is local
      return await super.put(accountToSave, syncSource: syncSource);
    }
  }

  /// Override putMany to handle syncSource correctly.
  @override
  Future<List<int>> putMany(List<Account> entities,
      {SyncSource syncSource = SyncSource.local}) async {
    List<int> resultIds = [];
    if (syncSource == SyncSource.supabase) {
      final entitiesToSave = entities
          .map((e) => e.copyWith(
              createdAt: e.createdAt.toLocal(),
              updatedAt: e.updatedAt.toLocal(),
              deletedAt: e.deletedAt?.toLocal()))
          .toList();
      resultIds = await super.putMany(entitiesToSave, syncSource: syncSource);
    } else {
      final currentUserId = _authService.currentUser?.id;
      final now = DateTime.now();
      final List<Account> processedEntities = [];
      // Get existing entities from DB to preserve createdAt for updates
      final existingIds =
          entities.map((e) => e.id).where((id) => id != 0).toList();
      final Map<int, Account> existingMap = {
        for (var e
            in (await box.getManyAsync(existingIds)).whereType<Account>())
          e.id: e
      };

      for (final entity in entities) {
        Account entityToSave;
        // Ensure entity.uuid is already unique if it's a new item from defaults
        if (entity.uuid == null && entity.id == 0) {
          // This case should ideally not happen if _initializeDefaultAccounts sets UUIDs.
          print(
              "Warning: Account entity passed to putMany with null UUID and id 0. Generating one.");
          entityToSave = entity.copyWith(
            uuid: Uuid().v4(), // Generate UUID if missing for a new item
            userId: currentUserId,
            createdAt:
                (entity.id == 0 || existingMap[entity.id]?.createdAt == null)
                    ? now
                    : existingMap[entity.id]!.createdAt,
            updatedAt: now,
            deletedAt: entity.deletedAt,
          );
        } else if (entity.id == 0) {
          // New entity, UUID should have been pre-assigned by caller
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: entity.deletedAt,
          );
        } else {
          // Existing entity
          final existing = existingMap[entity.id];
          entityToSave = entity.copyWith(
            userId: currentUserId,
            updatedAt: now,
            createdAt: existing?.createdAt ?? now,
            deletedAt: entity.deletedAt,
          );
        }
        processedEntities.add(entityToSave);
      }
      if (processedEntities.isNotEmpty) {
        resultIds =
            await super.putMany(processedEntities, syncSource: syncSource);

        // --- MODIFIED: Use pushUpsertMany (Fire-and-Forget) ---
        if (resultIds.isNotEmpty && syncService != null) {
          print(
              "Pushing ${resultIds.length} accounts after local putMany using pushUpsertMany (no await).");
          final savedItems =
              (await box.getManyAsync(resultIds)).whereType<Account>().toList();
          if (savedItems.isNotEmpty) {
            syncService!
                .pushUpsertMany<Account>(savedItems)
                .catchError((pushError) {
              print(
                  "Background push error during pushUpsertMany for Accounts: $pushError");
            });
          } else {
            print(
                "Warning: Could not fetch saved accounts after putMany for push.");
          }
        } else if (syncService == null) {
          print(
              "Warning: syncService is null in AccountRepository.putMany. Cannot push changes immediately.");
        }
        // --- END MODIFIED ---
      } else {
        resultIds = [];
      }
    }
    return resultIds;
  }

  Future<int> hardDeleteAllForCurrentUser() async {
    final userCondition = _userIdCondition();
    final query = box.query(userCondition).build();
    final items = await query.findAsync();
    query.close();
    if (items.isEmpty) return 0;
    final ids = items.map((c) => c.id).toList();

    // --- Push remote deletes to Supabase (fire-and-forget) ---
    if (syncService != null) {
      for (final item in items) {
        try {
          // Use pushDeleteByUuid to ensure remote deletion by uuid (Supabase expects uuid as PK)
          syncService!.pushDeleteByUuid('accounts', item.uuid).catchError((e) {
            print(
                "Supabase delete error for Account UUID ${item.uuid}: ${e.toString()}");
          });
        } catch (e) {
          print(
              "Exception during Supabase delete for Account UUID ${item.uuid}: ${e.toString()}");
        }
      }
    } else {
      print(
          "Warning: syncService is null in hardDeleteAllForCurrentUser. Cannot push remote deletes.");
    }
    // --- End remote delete ---

    await box.removeManyAsync(ids);
    print("Hard deleted ${ids.length} accounts for user.");
    return ids.length;
  }
}
