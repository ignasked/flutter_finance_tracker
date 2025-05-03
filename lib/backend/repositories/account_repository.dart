import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/models/transaction.dart';

class AccountRepository extends BaseRepository<Account> {
  final AuthService _authService;

  AccountRepository(Store store, this._authService) : super(store) {
    _initializeDefaultAccounts();
    _setDefaultAccount();
  }

  Future<void> _setDefaultAccount() async {
    final defaultAcc = await getById(1);
    if (defaultAcc != null) {
      Defaults().defaultAccount = defaultAcc;
    }
  }

  /// Factory method for asynchronous initialization
  static Future<AccountRepository> create(
      Store store, AuthService authService) async {
    return AccountRepository(store, authService);
  }

  Future<void> _initializeDefaultAccounts() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) {
      final defaultAcc = await getById(1);
      if (defaultAcc != null) {
        Defaults().defaultAccount = defaultAcc;
      }
      return;
    }
    final defaultAccounts = [
      Account(
        name: 'Bank Account',
        typeValue: AccountType.bank.index,
        currency: 'USD',
        currencySymbol: '\$',
        balance: 0.0,
        colorValue: Colors.blue.value,
        iconCodePoint: Icons.account_balance.codePoint,
      ),
      Account(
        name: 'Cash',
        typeValue: AccountType.cash.index,
        currency: 'USD',
        currencySymbol: '\$',
        balance: 0.0,
        colorValue: Colors.green.value,
        iconCodePoint: Icons.account_balance_wallet.codePoint,
      ),
    ];

    for (Account defaultAccount in defaultAccounts) {
      final supabase = Supabase.instance.client;
      defaultAccount =
          defaultAccount.copyWith(userId: supabase.auth.currentUser?.id);

      final query =
          box.query(Account_.name.equals(defaultAccount.name)).build();
      final exists = query.find().isNotEmpty;
      query.close();

      if (!exists) {
        try {
          await put(defaultAccount);
          print('Added default account: ${defaultAccount.name}');
        } catch (e) {
          print('Error adding default account ${defaultAccount.name}: $e');
        }
      }
    }

    final defaultAcc = await getById(1);
    if (defaultAcc != null) {
      Defaults().defaultAccount = defaultAcc;
    }
  }

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunchAccounts') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunchAccounts', false);
    }
    return isFirstLaunch;
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
      // Check if an account with the same ID already exists for the target user
      final existingUserItemQuery = box
          .query(Account_.id
              .equals(item.id)
              .and(Account_.userId.equals(newUserId)))
          .build();
      final existingUserItem = await existingUserItemQuery.findFirstAsync();
      existingUserItemQuery.close();

      if (existingUserItem != null) {
        print(
            "Skipping assignment for account ${item.id}: Already exists for user $newUserId.");
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
          "No accounts needed userId assignment after checking for existing entries.");
      return 0;
    }
  }

  /// Soft removes all accounts for the current user.
  Future<int> removeAllForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;
    if (currentUserId == null) {
      print(
          "Warn: Attempted to remove all accounts for current user, but no user is logged in.");
      return 0;
    }
    // Fetch non-deleted items first
    final query = box
        .query(
            Account_.userId.equals(currentUserId).and(_notDeletedCondition()))
        .build();
    final itemsToRemove = await query.findAsync();
    query.close();

    if (itemsToRemove.isEmpty) {
      print("No active accounts found for user $currentUserId to soft remove.");
      return 0;
    }

    int successCount = 0;
    int skippedCount = 0;
    for (final item in itemsToRemove) {
      if (await remove(item.id)) {
        successCount++;
      } else {
        skippedCount++;
      }
    }
    print("Soft removed $successCount accounts for user $currentUserId." +
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
