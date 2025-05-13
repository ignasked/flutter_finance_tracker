import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/base_repository.dart'; // <-- Add missing import
import 'package:money_owl/backend/services/auth_service.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart'; // Import FilterState
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncService
// Import TransactionType

class TransactionRepository extends BaseRepository<Transaction> {
  final AuthService _authService;
  SyncService? syncService; // <-- Make public and nullable

  // Modify constructor to accept nullable SyncService
  TransactionRepository(Store store, this._authService, this.syncService)
      : super(store);

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

  /// Override put to update timestamps, set userId, and push changes.
  @override
  Future<int> put(Transaction transaction,
      {SyncSource syncSource = SyncSource.local}) async {
    final currentUserId = _authService.currentUser?.id;
    int resultId = transaction.id; // Initialize with incoming ID

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
        );
      } else {
        // Existing transaction - fetch WITHOUT user filter to allow updates/restores
        final existing = await box.getAsync(transaction.id);
        if (existing == null) {
          print(
              "Warning: Attempted to update non-existent transaction ID: ${transaction.id}");
          return transaction.id; // Or throw?
        }
        // Check context *before* saving
        if (existing.userId != currentUserId) {
          // Allow update only if the existing userId is null (assignment case)
          if (existing.userId != null) {
            print(
                "Error: Attempted to update transaction with mismatched userId context. Existing: ${existing.userId}, Current: $currentUserId");
            throw Exception(
                "Cannot modify data belonging to a different user context.");
          }
          // If existing.userId is null, we allow the update (assignment)
          print(
              "Info: Assigning userId $currentUserId to transaction ID ${transaction.id}");
        }

        transactionToSave = transaction.copyWith(
          userId: currentUserId, // Ensure context is set/updated
          updatedAt: now, // Always update timestamp
          createdAt:
              transaction.createdAt != DateTime.fromMillisecondsSinceEpoch(0)
                  ? transaction.createdAt
                  : existing.createdAt, // Preserve original createdAt
          // copyWith handles deletedAt logic (including setDeletedAtNull)
        );
      }

      // Final check before saving
      if (transactionToSave.userId != currentUserId) {
        print(
            "Error: Mismatched userId (${transactionToSave.userId}) during save for current context ($currentUserId).");
        throw Exception("Data integrity error: User ID mismatch.");
      }

      // Use super.put to save locally
      resultId = await super.put(transactionToSave, syncSource: syncSource);

      // --- Push Change Immediately (Fire-and-Forget) ---
      if (resultId != 0 && syncService != null) {
        // Fetch the final saved item to ensure we push the correct state
        final savedItem = await box.getAsync(resultId);
        if (savedItem != null) {
          print(
              "Pushing change for Transaction ID $resultId immediately after local put (no await).");
          // Use try-catch within an unawaited Future for background error handling
          syncService!
              .pushSingleUpsert<Transaction>(savedItem)
              .catchError((pushError) {
            print(
                "Background push error for Transaction ID $resultId: $pushError");
            // Log error, but don't rethrow as it's in the background
          });
        } else {
          print(
              "Warning: Could not fetch Transaction ID $resultId after put for immediate push.");
        }
      } else if (syncService == null) {
        print(
            "Warning: syncService is null in TransactionRepository.put. Cannot push change immediately.");
      }
      // --- End Push Change ---

      return resultId; // Return immediately after local put
    } else {
      // Syncing down from Supabase
      if (transaction.userId == null) {
        print(
            "Warning: Syncing down transaction with null userId. ID: ${transaction.id}");
      }
      // Ensure dates are local
      final transactionToSave = transaction.copyWith(
          createdAt: transaction.createdAt.toLocal(),
          updatedAt: transaction.updatedAt.toLocal(),
          deletedAt: transaction.deletedAt?.toLocal());
      // Use super.put to bypass this override's logic
      return await super.put(transactionToSave, syncSource: syncSource);
    }
  }

  /// Fetch all non-deleted transactions for the current context.
  @override
  Future<List<Transaction>> getAll() async {
    try {
      final query =
          box.query(_userIdCondition().and(_notDeletedCondition())).build();
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
              .and(_notDeletedCondition()))
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
    // Fetch first to ensure it belongs to the current user before soft deleting
    final item = await getById(id); // Uses user context and notDeleted filter
    if (item == null) {
      print(
          "Soft remove failed: Transaction $id not found or doesn't belong to user ${_authService.currentUser?.id}.");
      return false;
    }
    // If found, proceed with base soft remove
    return await super.softRemove(id);
  }

  /// Restores a soft-deleted transaction by ID if it belongs to the current context.
  Future<bool> restoreTransaction(int id) async {
    // Fetch directly (including deleted) but check user context before restoring
    final currentUserId = _authService.currentUser?.id;
    final query = box
        .query(Transaction_.id
            .equals(id)
            .and(_userIdCondition())) // Check user context
        .build();
    final item = await query.findFirstAsync();
    query.close();

    if (item == null) {
      print(
          "Restore failed: Transaction $id not found or doesn't belong to user $currentUserId.");
      return false;
    }
    // If found and belongs to user, proceed with base restore
    return await super.restore(id);
  }

  /// Updates non-deleted transactions with null userId to the provided newUserId.
  /// Uses direct box access to bypass overridden put/putMany context checks for this specific task.
  Future<int> assignUserIdToNullEntries(String newUserId) async {
    final query = box
        .query(Transaction_.userId.isNull().and(_notDeletedCondition()))
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

    // Fetch existing UUIDs for the target user to prevent duplicates
    final userUuidQuery =
        box.query(Transaction_.userId.equals(newUserId)).build();
    final existingUserUuids =
        (await userUuidQuery.findAsync()).map((t) => t.uuid).toSet();
    userUuidQuery.close();

    int skippedCount = 0;
    for (final item in nullUserItems) {
      if (existingUserUuids.contains(item.uuid)) {
        print(
            "Skipping assignment for transaction UUID ${item.uuid}: Already exists for user $newUserId. Local item ID ${item.id}.");
        skippedCount++;
        continue;
      }
      updatedItems.add(item.copyWith(
        userId: newUserId,
        updatedAt: now, // IMPORTANT: Update timestamp
      ));
    }

    if (updatedItems.isNotEmpty) {
      try {
        // Use box.putManyAsync directly for this specific assignment task
        await box.putManyAsync(updatedItems);
        final successCount = updatedItems.length;
        print(
            "Successfully assigned userId $newUserId to $successCount transactions. Skipped $skippedCount due to existing UUIDs.");
        return successCount;
      } catch (e) {
        print(
            "Error during direct putManyAsync in assignUserIdToNullEntries: $e");
        return 0; // Indicate failure
      }
    } else {
      print(
          "No transactions needed userId assignment after checking for existing entries by UUID.");
      return 0;
    }
  }

  /// Soft deletes all transactions for the currently logged-in user.
  /// If no user is logged in, soft deletes transactions with a null userId.
  Future<int> removeAllForCurrentUser() async {
    final query =
        box.query(_userIdCondition().and(_notDeletedCondition())).build();
    final itemsToDelete = await query.findAsync();
    query.close();

    if (itemsToDelete.isEmpty) {
      print(
          "No transactions found to delete for user: ${_authService.currentUser?.id ?? 'unauthenticated'}");
      return 0;
    }

    final List<Transaction> itemsToSoftDelete = [];
    final now = DateTime.now();
    final nowUtc = now.toUtc();
    for (final item in itemsToDelete) {
      itemsToSoftDelete.add(item.copyWith(
        deletedAt: nowUtc,
        updatedAt: now, // Update timestamp for sync
      ));
    }

    try {
      // Use box.putManyAsync directly
      await box.putManyAsync(itemsToSoftDelete);
      print(
          "Soft removed ${itemsToSoftDelete.length} transactions locally for user: ${_authService.currentUser?.id ?? 'unauthenticated'}");
      return itemsToSoftDelete.length;
    } catch (e) {
      print("Error during direct putManyAsync in removeAllForCurrentUser: $e");
      return 0; // Return 0 as local write failed, though push was attempted
    }
  }

  /// Hard deletes all transactions for the currently logged-in user, including remote (Supabase) deletion.
  Future<int> hardDeleteAllForCurrentUser() async {
    final userCondition = _userIdCondition();
    final query = box.query(userCondition).build();
    final items = await query.findAsync();
    query.close();
    if (items.isEmpty) return 0;
    final ids = items.map((t) => t.id).toList();

    // --- Push remote deletes to Supabase (fire-and-forget) ---
    if (syncService != null) {
      for (final item in items) {
        try {
          // Use pushDeleteByUuid to ensure remote deletion by uuid (Supabase expects uuid as PK)
          syncService!
              .pushDeleteByUuid('transactions', item.uuid)
              .catchError((e) {
            print(
                "Supabase delete error for Transaction UUID ${item.uuid}: ${e.toString()}");
          });
        } catch (e) {
          print(
              "Exception during Supabase delete for Transaction UUID ${item.uuid}: ${e.toString()}");
        }
      }
    } else {
      print(
          "Warning: syncService is null in hardDeleteAllForCurrentUser. Cannot push remote deletes.");
    }
    // --- End remote delete ---

    await box.removeManyAsync(ids);
    print(
        "Hard deleted ${ids.length} transactions for user (local and remote).");
    return ids.length;
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
      final List<Transaction> processedEntities = [];

      final existingIds =
          entities.map((e) => e.id).where((id) => id != 0).toList();
      final existingMap = {
        for (var e
            in (await box.getManyAsync(existingIds)).whereType<Transaction>())
          e.id: e
      };

      for (final entity in entities) {
        Transaction entityToSave;
        if (entity.id == 0) {
          entityToSave = entity.copyWith(
            userId: currentUserId,
            createdAt: now,
            updatedAt: now,
            deletedAt: entity.deletedAt,
          );
        } else {
          final existing = existingMap[entity.id];
          if (existing == null) {
            print(
                "Warning: Skipping update for transaction ID ${entity.id} in putMany (not found).");
            continue;
          }

          if (existing.userId != null && existing.userId != currentUserId) {
            print(
                "Warning: Skipping update for transaction ID ${entity.id} in putMany (context mismatch: existing=${existing.userId}, current=$currentUserId).");
            continue;
          }

          entityToSave = entity.copyWith(
            userId: currentUserId,
            updatedAt: now,
            createdAt: existing.createdAt,
          );
        }

        if (entityToSave.userId != currentUserId) {
          print(
              "Error: Mismatched userId (${entityToSave.userId}) during putMany processing for current context ($currentUserId). Skipping ID ${entity.id}.");
          continue;
        }
        processedEntities.add(entityToSave);
      }

      if (processedEntities.isNotEmpty) {
        resultIds =
            await super.putMany(processedEntities, syncSource: syncSource);

        // --- MODIFIED: Use pushUpsertMany (Fire-and-Forget) ---
        if (resultIds.isNotEmpty && syncService != null) {
          print(
              "Pushing ${resultIds.length} transactions after local putMany using pushUpsertMany (no await).");
          // Fetch the saved items to ensure we push the correct state
          final savedItems = (await box.getManyAsync(resultIds))
              .whereType<Transaction>()
              .toList();
          if (savedItems.isNotEmpty) {
            // Call pushUpsertMany without await and catch errors
            syncService!
                .pushUpsertMany<Transaction>(savedItems)
                .catchError((pushError) {
              print(
                  "Background push error during pushUpsertMany for Transactions: $pushError");
            });
          } else {
            print(
                "Warning: Could not fetch saved transactions after putMany for push.");
          }
        } else if (syncService == null) {
          print(
              "Warning: syncService is null in TransactionRepository.putMany. Cannot push changes immediately.");
        }
        // --- END MODIFIED ---
      } else {
        resultIds = [];
      }
    }
    return resultIds;
  }

  /// Fetch filtered transactions for the current context, excluding soft-deleted ones.
  Future<List<Transaction>> getFiltered(FilterState filterState) async {
    try {
      Condition<Transaction> queryCondition =
          _userIdCondition().and(_notDeletedCondition());

      Condition<Transaction> addCondition(
          Condition<Transaction>? currentCombined,
          Condition<Transaction> newCondition) {
        return currentCombined == null
            ? newCondition
            : currentCombined.and(newCondition);
      }

      Condition<Transaction>? combinedPropertyCondition;
      if (filterState.startDate != null) {
        Condition<Transaction>? dateCondition;
        if (filterState.singleDay) {
          final startOfDay = DateTime(filterState.startDate!.year,
              filterState.startDate!.month, filterState.startDate!.day);
          final endOfDay = startOfDay.add(const Duration(days: 1));
          dateCondition = Transaction_.date
              .greaterOrEqual(startOfDay.millisecondsSinceEpoch)
              .and(Transaction_.date.lessThan(endOfDay.millisecondsSinceEpoch));
        } else {
          final rangeStart = filterState.startDate!;
          Condition<Transaction> startCondition = Transaction_.date
              .greaterOrEqual(rangeStart.millisecondsSinceEpoch);
          if (filterState.endDate != null) {
            final rangeEnd = filterState.endDate!.add(const Duration(days: 1));
            dateCondition = startCondition.and(
                Transaction_.date.lessThan(rangeEnd.millisecondsSinceEpoch));
          } else {
            dateCondition = startCondition;
          }
        }
        combinedPropertyCondition =
            addCondition(combinedPropertyCondition, dateCondition);
      }

      if (filterState.minAmount != null) {
        print(
            "Warning: Amount filtering might not work as expected with ObjectBox query conditions on absolute values. Filtering >= ${filterState.minAmount}");
        final amountCondition =
            Transaction_.amount.greaterOrEqual(filterState.minAmount!);
        combinedPropertyCondition =
            addCondition(combinedPropertyCondition, amountCondition);
      }

      if (filterState.isIncome != null) {
        Condition<Transaction> typeCondition;
        if (filterState.isIncome!) {
          typeCondition = Transaction_.amount.greaterThan(0);
        } else {
          typeCondition = Transaction_.amount.lessThan(0);
        }
        combinedPropertyCondition =
            addCondition(combinedPropertyCondition, typeCondition);
      }

      if (combinedPropertyCondition != null) {
        queryCondition = queryCondition.and(combinedPropertyCondition);
      }

      var queryBuilder = box.query(queryCondition);

      if (filterState.selectedAccount != null) {
        queryBuilder.link(Transaction_.fromAccount,
            Account_.id.equals(filterState.selectedAccount!.id));
      }
      if (filterState.selectedCategories.isNotEmpty) {
        final categoryIds =
            filterState.selectedCategories.map((c) => c.id).toList();
        queryBuilder.link(
            Transaction_.category, Category_.id.oneOf(categoryIds));
      }

      queryBuilder.order(Transaction_.date, flags: Order.descending);

      final query = queryBuilder.build();
      final results = await query.findAsync();
      query.close();
      return results;
    } catch (e, stacktrace) {
      print("Error fetching filtered transactions: $e");
      print(stacktrace);
      return [];
    }
  }

  /// Fetch multiple transactions by their IDs for the current context.
  /// Optionally includes soft-deleted items.
  Future<List<Transaction>> getManyByIds(List<int> ids,
      {bool includeDeleted = false}) async {
    if (ids.isEmpty) return [];
    final uniqueIds = ids.where((id) => id != 0).toSet().toList();
    if (uniqueIds.isEmpty) return [];

    try {
      Condition<Transaction> condition =
          Transaction_.id.oneOf(uniqueIds) & _userIdCondition();

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

  /// Checks if any non-deleted transactions exist with a null userId.
  Future<bool> hasLocalOnlyData() async {
    try {
      final query = box
          .query(Transaction_.userId.isNull().and(_notDeletedCondition()))
          .build();
      final count = query.count();
      query.close();
      return count > 0;
    } catch (e) {
      print("Error checking for local-only transaction data: $e");
      return false;
    }
  }
}
