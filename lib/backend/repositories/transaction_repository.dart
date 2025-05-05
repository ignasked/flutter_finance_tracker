import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:objectbox/objectbox.dart';
import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncSource

class TransactionRepository extends BaseRepository<Transaction> {
  final AuthService _authService;

  TransactionRepository(Store store, this._authService) : super(store);

  /// Get the user ID condition based on auth state.
  Condition<Transaction> _userIdCondition() {
    final currentUserId = _authService.currentUser?.id;
    return currentUserId != null
        ? Transaction_.userId.equals(currentUserId)
        : Transaction_.userId.isNull();
  }

  /// Condition to filter out soft-deleted items.
  Condition<Transaction> _notDeletedCondition() {
    return Transaction_.deletedAt.isNull();
  }

  /// Get transactions modified after a specific time (UTC) for the current context.
  /// Includes soft-deleted items for syncing.
  Future<List<Transaction>> getAllModifiedSince(DateTime time) async {
    final query = box
        .query(Transaction_.updatedAt
            .greaterThan(time.toUtc().millisecondsSinceEpoch)
            .and(_userIdCondition())) // Filter by user
        .build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Override put to update timestamps and set userId based on auth state.
  @override
  Future<int> put(Transaction transaction,
      {SyncSource syncSource = SyncSource.local}) async {
    final currentUserId = _authService.currentUser?.id;

    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Transaction transactionToSave;

      if (transaction.id == 0) {
        // New transaction
        transactionToSave = transaction.copyWith(
          userId: currentUserId,
          createdAt: now,
          updatedAt: now,
          deletedAt: transaction.deletedAt, // Preserve if explicitly set
          categoryId: transaction.category.targetId,
          fromAccountId: transaction.fromAccount.targetId,
          toAccountId: transaction.toAccount.targetId == 0
              ? null
              : transaction.toAccount.targetId,
        );
      } else {
        // Existing transaction - fetch directly to handle updates/restores
        final existing = await box.getAsync(transaction.id);
        if (existing == null) {
          print(
              "Warning: Attempted to update non-existent transaction ID: ${transaction.id}");
          throw Exception(
              "Cannot update non-existent transaction ID ${transaction.id}");
        }
        if (existing.userId != currentUserId) {
          print(
              "Error: Attempted to update transaction with mismatched userId context. Existing: ${existing.userId}, Current: $currentUserId");
          throw Exception(
              "Cannot modify data belonging to a different user context.");
        }

        // Apply changes from the incoming 'transaction' onto the 'existing' one
        transactionToSave = existing.copyWith(
          title: transaction.title,
          amount: transaction.amount,
          description: transaction.description,
          date: transaction.date,
          categoryId: transaction.category.targetId,
          fromAccountId: transaction.fromAccount.targetId,
          toAccountId: transaction.toAccount.targetId == 0
              ? null
              : transaction.toAccount.targetId,
          updatedAt: now,
          userId: currentUserId,
          metadata: transaction.metadata,
          deletedAt: transaction.deletedAt,
        );
      }

      // Final check before saving
      if (transactionToSave.userId != currentUserId) {
        print(
            "Error: Mismatched userId (${transactionToSave.userId}) during save for current context ($currentUserId). Transaction ID: ${transactionToSave.id}");
        throw Exception("Data integrity error: User ID mismatch before save.");
      }
      return await super.put(transactionToSave, syncSource: syncSource);
    } else {
      // Syncing down from Supabase
      if (transaction.userId == null) {
        print(
            "Warning: Syncing down transaction with null userId. ID: ${transaction.id}");
      }
      final transactionToSave = transaction.copyWith(
          createdAt: transaction.createdAt.toLocal(),
          updatedAt: transaction.updatedAt.toLocal(),
          deletedAt: transaction.deletedAt?.toLocal(),
          categoryId: transaction.category.targetId,
          fromAccountId: transaction.fromAccount.targetId,
          toAccountId: transaction.toAccount.targetId);
      return await super.put(transactionToSave, syncSource: syncSource);
    }
  }

  /// Fetch all non-deleted transactions for the current context.
  @override
  Future<List<Transaction>> getAll() async {
    try {
      final query = box
          .query(_userIdCondition()
              .and(_notDeletedCondition())) // Filter by user and not deleted
          .order(Transaction_.date,
              flags: Order.descending) // Order by date descending
          .build();
      final results = await query.findAsync();
      query.close();
      return results;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print('Error fetching transactions for context $context: $e');
      return [];
    }
  }

  /// Fetch a transaction by ID if it belongs to the current context and is not soft-deleted.
  @override
  Future<Transaction?> getById(int id) async {
    try {
      final query = box
          .query(Transaction_.id
              .equals(id)
              .and(_userIdCondition())
              .and(_notDeletedCondition())) // Filter by user and not deleted
          .build();
      final result = await query.findFirstAsync();
      query.close();
      return result;
    } catch (e) {
      final context = _authService.currentUser?.id ?? 'local (unauthenticated)';
      print("Error fetching transaction $id for context $context: $e");
      return null;
    }
  }

  /// Soft removes a transaction by ID if it belongs to the current context.
  @override
  Future<bool> remove(int id) async {
    return await super.softRemove(id);
  }

  /// Restores a soft-deleted transaction by ID if it belongs to the current context.
  Future<bool> restoreTransaction(int id) async {
    return await super.restore(id);
  }

  /// Updates non-deleted transactions with null userId to the provided newUserId.
  Future<int> assignUserIdToNullEntries(String newUserId) async {
    final query = box
        .query(Transaction_.userId
            .isNull()
            .and(_notDeletedCondition())) // Only non-deleted
        .build();
    final nullUserItems = await query.findAsync();
    query.close();

    if (nullUserItems.isEmpty) {
      return 0;
    }

    print(
        "Assigning userId $newUserId to ${nullUserItems.length} local-only transactions...");

    final List<Transaction> updatedItems = [];
    final now = DateTime.now();

    for (final item in nullUserItems) {
      final existingUserItemQuery = box
          .query(Transaction_.uuid
              .equals(item.uuid)
              .and(Transaction_.userId.equals(newUserId)))
          .build();
      final existingUserItem = await existingUserItemQuery.findFirstAsync();
      existingUserItemQuery.close();

      if (existingUserItem != null) {
        print(
            "Skipping assignment for transaction UUID ${item.uuid}: Already exists for user $newUserId with ID ${existingUserItem.id}. Consider merging or deleting local item ID ${item.id}.");
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
          "Successfully assigned userId $newUserId to ${updatedItems.length} transactions.");
      return updatedItems.length;
    } else {
      print(
          "No transactions needed userId assignment after checking for existing entries by UUID.");
      return 0;
    }
  }

  /// Soft deletes all transactions for the currently logged-in user.
  /// If no user is logged in, soft deletes transactions with a null userId.
  Future<int> removeAllForCurrentUser() async {
    final currentUserId = _authService.currentUser?.id;

    // If user is logged in, target their ID. If not logged in, target null userId.
    final queryBuilder = currentUserId != null
        ? box.query(Transaction_.userId.equals(currentUserId) &
            Transaction_.deletedAt
                .isNull()) // Existing condition for logged-in user
        : box.query(Transaction_.userId.isNull() &
            Transaction_.deletedAt.isNull()); // Condition for logged-out user

    final transactionsToDelete = await queryBuilder.build().findAsync();
    if (transactionsToDelete.isEmpty) {
      print(
          "No transactions found to delete for user: ${currentUserId ?? 'unauthenticated'}");
      return 0;
    }

    final now = DateTime.now();
    // Create new instances with deletedAt set
    final List<Transaction> updatedTransactions = transactionsToDelete
        .map((transaction) => transaction.copyWith(deletedAt: now))
        .toList();

    // Save the updated instances, replacing the old ones
    await box.putManyAsync(updatedTransactions);

    print(
        "Soft deleted ${updatedTransactions.length} transactions for user: ${currentUserId ?? 'unauthenticated'}");
    return updatedTransactions.length;
  }

  /// Override removeAll from BaseRepository.
  @override
  Future<int> removeAll() async {
    print(
        "Error: Direct call to removeAll() is disabled for safety. Use removeAllForCurrentUser() instead.");
    throw UnimplementedError(
        "Use removeAllForCurrentUser() to soft-delete user-specific data.");
  }

  /// Override putMany to handle syncSource correctly and optimize relation lookups.
  @override
  Future<List<int>> putMany(List<Transaction> entities,
      {SyncSource syncSource = SyncSource.local}) async {
    if (syncSource == SyncSource.supabase) {
      // Keep Supabase sync logic as is (assuming it's already optimized or different)
      final entitiesToSave = entities
          .map((e) => e.copyWith(
              createdAt: e.createdAt.toLocal(),
              updatedAt: e.updatedAt.toLocal(),
              deletedAt: e.deletedAt?.toLocal(),
              categoryId: e.category.targetId,
              fromAccountId: e.fromAccount.targetId,
              toAccountId: e.toAccount.targetId))
          .toList();
      return await super.putMany(entitiesToSave, syncSource: syncSource);
    } else {
      // --- Optimization for Local Puts ---
      final currentUserId = _authService.currentUser?.id;
      final now = DateTime.now();
      final List<Transaction> processedEntities = [];

      // --- Batch Fetch Relations ---
      final categoryRepo = CategoryRepository(store, _authService);
      final accountRepo = AccountRepository(store, _authService);

      // Extract unique, non-zero IDs
      final categoryIds = entities
          .map((e) => e.category.targetId)
          .where((id) => id != 0)
          .toSet()
          .toList();
      final fromAccountIds = entities
          .map((e) => e.fromAccount.targetId)
          .where((id) => id != 0)
          .toSet()
          .toList();
      final toAccountIds = entities
          .map((e) => e.toAccount.targetId)
          .where((id) => id != 0)
          .toSet()
          .toList();
      final allAccountIds =
          {...fromAccountIds, ...toAccountIds}.toList(); // Combine and unique

      // Fetch in parallel
      final List<List<dynamic>> results = await Future.wait([
        if (categoryIds.isNotEmpty)
          categoryRepo.getManyByIds(categoryIds)
        else
          Future.value([]),
        if (allAccountIds.isNotEmpty)
          accountRepo.getManyByIds(allAccountIds)
        else
          Future.value([]),
      ]);

      final List<Category> fetchedCategories = results[0].cast<Category>();
      final List<Account> fetchedAccounts = results[1].cast<Account>();

      // Create lookup maps
      final categoryMap = {for (var cat in fetchedCategories) cat.id: cat};
      final accountMap = {for (var acc in fetchedAccounts) acc.id: acc};
      // --- End Batch Fetch ---

      for (final entity in entities) {
        Transaction entityToSave;

        // --- Use Maps for Lookup ---
        // Use fetched category or default if not found or ID was 0
        Category attachedCategory =
            categoryMap[entity.category.targetId] ?? Defaults().defaultCategory;

        // Use fetched account or default if not found or ID was 0
        Account attachedFromAccount = accountMap[entity.fromAccount.targetId] ??
            Defaults().defaultAccount;

        // Use fetched account (can be null if ID was 0 or not found)
        Account? attachedToAccount = accountMap[entity.toAccount.targetId];
        // --- End Use Maps ---

        if (entity.id == 0) {
          // New entity
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: entity.deletedAt,
            categoryId: attachedCategory.id, // Use ID from map/default
            fromAccountId: attachedFromAccount.id, // Use ID from map/default
            toAccountId: attachedToAccount?.id, // Use ID from map (nullable)
          );
        } else {
          // Existing entity
          // Fetch existing only if necessary (e.g., to preserve createdAt)
          // For performance, consider if fetching existing is always needed.
          // If only updating, we might skip this fetch, but it's safer to include.
          final existing = await box.getAsync(entity.id);
          if (existing != null && existing.userId == currentUserId) {
            entityToSave = existing.copyWith(
              title: entity.title,
              amount: entity.amount,
              description: entity.description,
              date: entity.date,
              categoryId: attachedCategory.id, // Use ID from map/default
              fromAccountId: attachedFromAccount.id, // Use ID from map/default
              toAccountId: attachedToAccount?.id, // Use ID from map (nullable)
              metadata: entity.metadata,
              updatedAt: now, // Always update timestamp
              deletedAt: entity.deletedAt, // Preserve incoming deletedAt status
              userId: currentUserId, // Ensure context
            );
          } else {
            print(
                "Warning: Skipping update for transaction ID ${entity.id} in putMany (not found or context mismatch).");
            continue; // Skip this entity
          }
        }

        // Final context check
        if (entityToSave.userId != currentUserId) {
          print(
              "Error: Mismatched userId in putMany for transaction ID ${entityToSave.id}. Skipping.");
          continue; // Skip this entity
        }
        processedEntities.add(entityToSave);
      } // End loop

      // Perform the batch database write
      return await super.putMany(processedEntities, syncSource: syncSource);
    }
  }

  /// Fetch filtered transactions for the current context, excluding soft-deleted ones.
  Future<List<Transaction>> getFiltered(FilterState filterState) async {
    Condition<Transaction> queryCondition =
        _userIdCondition().and(_notDeletedCondition());

    if (filterState.selectedAccount != null) {
      queryCondition = queryCondition.and(
          Transaction_.fromAccount.equals(filterState.selectedAccount!.id));
    }

    if (filterState.selectedCategories.isNotEmpty) {
      final categoryIds =
          filterState.selectedCategories.map((c) => c.id).toList();
      queryCondition =
          queryCondition.and(Transaction_.category.oneOf(categoryIds));
    }

    if (filterState.startDate != null) {
      if (filterState.singleDay) {
        final startOfDay = DateTime(filterState.startDate!.year,
            filterState.startDate!.month, filterState.startDate!.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        queryCondition = queryCondition.and(Transaction_.date
            .greaterOrEqual(startOfDay.millisecondsSinceEpoch)
            .and(Transaction_.date.lessThan(endOfDay.millisecondsSinceEpoch)));
      } else {
        final rangeStart = filterState.startDate!;
        final rangeEnd = filterState.endDate?.add(const Duration(days: 1));
        queryCondition = queryCondition.and(Transaction_.date
            .greaterOrEqual(rangeStart.millisecondsSinceEpoch));
        if (rangeEnd != null) {
          queryCondition = queryCondition
              .and(Transaction_.date.lessThan(rangeEnd.millisecondsSinceEpoch));
        }
      }
    }

    if (filterState.minAmount != null) {}

    if (filterState.isIncome != null) {}

    final query = box
        .query(queryCondition)
        .order(Transaction_.date, flags: Order.descending)
        .build();

    List<Transaction> results = await query.findAsync();
    query.close();

    if (filterState.minAmount != null) {
      results = results
          .where((t) => t.amount.abs() >= filterState.minAmount!)
          .toList();
    }

    if (filterState.isIncome != null) {
      results =
          results.where((t) => t.isIncome == filterState.isIncome).toList();
    }

    return results;
  }

  /// Fetch multiple transactions by their IDs for the current context.
  /// Optionally includes soft-deleted items.
  Future<List<Transaction>> getManyByIds(List<int> ids,
      {bool includeDeleted = false}) async {
    if (ids.isEmpty) return [];
    // Remove duplicates and 0 if present
    final uniqueIds = ids.where((id) => id != 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    try {
      // Base condition: match IDs and user context
      Condition<Transaction> condition =
          Transaction_.id.oneOf(uniqueIds) & _userIdCondition();

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
      print('Error fetching multiple transactions for context $context: $e');
      return [];
    }
  }
}
