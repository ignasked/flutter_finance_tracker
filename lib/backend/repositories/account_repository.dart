import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle

class AccountRepository extends BaseRepository<Account> {
  final AuthService _authService;

  AccountRepository(Store store, this._authService) : super(store);

  Future<void> init() async {
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

  // Define default data with stable UUIDs
  List<Account> get defaultAccountsData => [
        Account(
          uuid: 'f47ac10b-58cc-4372-a567-0e02b2c3d479', // Stable UUID for Bank
          name: 'Bank Account',
          typeValue: AccountType.bank.index,
          currency: Defaults().defaultCurrency, // Use loaded default currency
          currencySymbol: Defaults().defaultCurrencySymbol,
          balance: 0.0,
          colorValue:
              AppStyle.predefinedColors[0].value, // Use color from AppStyle
          iconCodePoint: AppStyle.predefinedIcons[20]
              .codePoint, // Use account_balance_outlined from AppStyle
        ),
        Account(
          uuid: 'a1b2c3d4-e5f6-7890-1234-567890abcdef', // Stable UUID for Cash
          name: 'Cash',
          typeValue: AccountType.cash.index,
          currency: Defaults().defaultCurrency, // Use loaded default currency
          currencySymbol: Defaults().defaultCurrencySymbol,
          balance: 0.0,
          colorValue:
              AppStyle.predefinedColors[1].value, // Use color from AppStyle
          iconCodePoint: AppStyle.predefinedIcons[21]
              .codePoint, // Use account_balance_wallet_outlined from AppStyle
        )
      ];

  /// Factory method for asynchronous initialization
  static Future<AccountRepository> create(
      Store store, AuthService authService) async {
    // Ensure Defaults are loaded before repository uses them
    await Defaults().loadDefaults();
    return AccountRepository(store, authService);
  }

  /// Initializes default accounts if they don't exist (based on UUID)
  /// Does NOT set the default instance in the Defaults singleton.
  Future<void> _initializeDefaultAccounts() async {
    final userCondition = _userIdCondition();
    final notDeleted = _notDeletedCondition();
    final primaryDefaultUuid = defaultAccountsData.first.uuid;

    // 1. Check if the primary default account exists for the user context
    final defaultAccQuery = box
        .query(Account_.uuid
            .equals(primaryDefaultUuid)
            .and(userCondition)
            .and(notDeleted))
        .build();
    final bool primaryExists = defaultAccQuery.count() > 0;
    defaultAccQuery.close();

    // 2. If primary default exists, just ensure others are present
    if (primaryExists) {
      print(
          "Primary default account found (UUID: $primaryDefaultUuid). Ensuring others exist.");

      // Ensure other default accounts also exist (optional, but good practice)
      await _ensureOtherDefaultAccountsExist(userCondition);

      return; // Initialization check done
    }

    // 3. If primary default NOT found, it might be first launch or new user context
    print("Primary default account not found. Initializing defaults...");

    // Get existing account UUIDs for the current context
    final existingUuidsQuery = box.query(userCondition).build();
    final existingUuids =
        (await existingUuidsQuery.findAsync()).map((a) => a.uuid).toSet();
    existingUuidsQuery.close();

    // Filter default accounts that don't exist yet based on UUID
    final List<Account> accountsToAdd = defaultAccountsData
        .where((defaultAccount) => !existingUuids.contains(defaultAccount.uuid))
        .toList();

    // Batch insert the missing accounts
    if (accountsToAdd.isNotEmpty) {
      try {
        print('Adding ${accountsToAdd.length} default accounts...');
        // Use putMany which handles setting userId and timestamps for local source
        await putMany(accountsToAdd, syncSource: SyncSource.local);
        print('Added default accounts successfully.');
      } catch (e) {
        print('Error adding default accounts: $e');
        // Decide if we should proceed or rethrow
      }
    } else {
      print("All default accounts already exist (UUID check).");
    }
  }

  /// Helper to ensure non-primary default accounts exist.
  Future<void> _ensureOtherDefaultAccountsExist(
      Condition<Account> userCondition) async {
    final otherDefaultUuids =
        defaultAccountsData.skip(1).map((a) => a.uuid).toList();
    if (otherDefaultUuids.isEmpty) return;

    final existingUuidsQuery = box
        .query(userCondition.and(Account_.uuid.oneOf(otherDefaultUuids)))
        .build();
    final existingUuids =
        (await existingUuidsQuery.findAsync()).map((a) => a.uuid).toSet();
    existingUuidsQuery.close();

    final List<Account> accountsToAdd = defaultAccountsData
        .skip(1)
        .where((acc) => !existingUuids.contains(acc.uuid))
        .toList();

    if (accountsToAdd.isNotEmpty) {
      print(
          'Ensuring other default accounts exist: Adding ${accountsToAdd.length} missing accounts.');
      try {
        await putMany(accountsToAdd, syncSource: SyncSource.local);
      } catch (e) {
        print('Error ensuring other default accounts exist: $e');
      }
    }
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
    final count = await query.count();
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

  /// Soft removes an account by ID if it belongs to the current context.
  /// Returns true if successful, false otherwise.
  @override
  Future<bool> remove(int id) async {
    final hasTransactions = await _hasTransactionsForAccount(id);
    if (hasTransactions) {
      print(
          "Soft remove failed: Account $id is still linked to active transactions.");
      return false;
    }
    return await super.softRemove(id);
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
        Account_.id.greaterThan(defaultAccountsData.length);

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

    // Iterates and calls remove(id) which performs soft delete
    int successCount = 0;
    int skippedCount = 0;
    for (final account in accountsToDelete) {
      if (await remove(account.id)) {
        // remove calls super.softRemove
        successCount++;
      } else {
        skippedCount++;
      }
    }
    print(
        "Soft removed $successCount accounts for user: ${currentUserId ?? 'unauthenticated'}." +
            (skippedCount > 0
                ? " Skipped $skippedCount due to active transactions."
                : ""));
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

  /// Override put to update timestamps and set userId based on auth state.
  @override
  Future<int> put(Account account,
      {SyncSource syncSource = SyncSource.local}) async {
    final currentUserId = _authService.currentUser?.id;

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
          print(
              "Error: Attempted to update account with mismatched userId context. Existing: ${existing.userId}, Current: $currentUserId");
          throw Exception(
              "Cannot modify data belonging to a different user context.");
        }

        accountToSave = account.copyWith(
          userId: currentUserId, // Ensure context
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
      return await super.put(accountToSave, syncSource: syncSource);
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
    if (syncSource == SyncSource.supabase) {
      final entitiesToSave = entities
          .map((e) => e.copyWith(
              createdAt: e.createdAt.toLocal(),
              updatedAt: e.updatedAt.toLocal(),
              deletedAt: e.deletedAt?.toLocal()))
          .toList();
      return await super.putMany(entitiesToSave, syncSource: syncSource);
    } else {
      final currentUserId = _authService.currentUser?.id;
      final now = DateTime.now();
      final List<Account> processedEntities = [];
      for (final entity in entities) {
        Account entityToSave;
        if (entity.id == 0) {
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: entity.deletedAt, // Preserve if explicitly set
          );
        } else {
          // Assume context check is less critical in batch, but ensure update time
          entityToSave = entity.copyWith(
            userId: currentUserId, // Ensure context
            updatedAt: now,
            // Preserve createdAt and deletedAt unless explicitly changed in the entity
            createdAt:
                entity.createdAt != DateTime.fromMillisecondsSinceEpoch(0)
                    ? entity.createdAt
                    : now, // Fallback, ideally fetch existing
          );
        }
        processedEntities.add(entityToSave);
      }
      return await super.putMany(processedEntities, syncSource: syncSource);
    }
  }
}
