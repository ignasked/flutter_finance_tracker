import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/services/auth_service.dart'; // Import AuthService
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../objectbox.g.dart'; // Adjust path as necessary
import 'package:objectbox/objectbox.dart';
import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncSource

class TransactionRepository extends BaseRepository<Transaction> {
  // No need for _supabaseClient here if SyncService handles Supabase interactions
  final SupabaseClient _authService; // Add AuthService

  // Inject AuthService
  TransactionRepository(Store store, this._authService) : super(store);

  /// Get transactions modified after a specific time (UTC) for the current user.
  Future<List<Transaction>> getAllModifiedSince(DateTime time) async {
    const currentUserId = "_authService.accessToken?.toString()";

    // Ensure comparison is done with UTC timestamps in the database
    final query = box
        .query(Transaction_.updatedAt
            .greaterThan(time.toUtc().millisecondsSinceEpoch)
            .and(Transaction_.userId
                .equals(currentUserId))) // Corrected: Use Transaction_.userId
        .build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Override put to update timestamps and set userId before saving.
  @override
  Future<int> put(Transaction transaction,
      {SyncSource syncSource = SyncSource.local}) async {
    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Transaction transactionToSave;
      const currentUserId = "_authService.currentUser?.id";

      if (transaction.id == 0) {
        // New transaction: set userId, createdAt, updatedAt
        transactionToSave = transaction.copyWith(
          userId: currentUserId, // Set user ID
          createdAt: now,
          updatedAt: now,
        );
      } else {
        // Existing transaction: update updatedAt, ensure userId is preserved/correct
        transactionToSave = transaction.copyWith(
          userId: transaction.userId ?? currentUserId, // Ensure userId is set
          updatedAt: now,
        );
      }

      // Safety check: Ensure the userId being saved matches the logged-in user
      if (transactionToSave.userId != currentUserId) {
        print(
            "Error: Attempted to save transaction with mismatched userId (${transactionToSave.userId}) for current user ($currentUserId).");
        throw Exception("Cannot save data for a different user.");
      }

      final savedId =
          await super.put(transactionToSave, syncSource: syncSource);
      // Optional: Trigger immediate push via SyncService if needed
      // context.read<SyncService>().pushUpsert('transactions', transactionToSave);
      return savedId;
    } else {
      // Syncing down from Supabase
      // userId should already be set from fromJson
      // Link relations if needed (existing logic can be kept or refined)
      // ... existing relation linking logic ...
      return await super.put(transaction, syncSource: syncSource);
    }
  }

  /// Fetch all transactions for the current user and ensure relations are loaded.
  @override
  Future<List<Transaction>> getAll() async {
    const currentUserId = "_authService.currentUser?.id";

    try {
      final query =
          box.query(Transaction_.userId.equals(currentUserId)).build();
      final transactions = await query.findAsync();
      query.close();

      // Manually trigger lazy-loading (consider eager loading if performance is an issue)
      // This is synchronous but ensures data is available if accessed immediately after.
      for (final transaction in transactions) {
        transaction.category.target;
        transaction.fromAccount.target;
        // transaction.toAccount.target; // If applicable
      }
      return transactions;
    } catch (e) {
      print('Error fetching transactions for user $currentUserId: $e');
      return [];
    }
  }

  // Fetch all transactions and check if any are associated with the category (now async)
  Future<bool> hasTransactionsForCategory(int categoryId) async {
    try {
      // Use await
      final transactions = await super.getAll();
      return transactions
          .any((transaction) => transaction.category.targetId == categoryId);
    } catch (e) {
      print('Error checking transactions for category $categoryId: $e');
      return false;
    }
  }

  // Fetch all transactions and check if any are associated with the account (now async)
  Future<bool> hasTransactionsForAccount(int accountId) async {
    try {
      // Use await
      final transactions = await super.getAll();
      return transactions
          .any((transaction) => transaction.fromAccount.targetId == accountId);
    } catch (e) {
      print('Error checking transactions for account $accountId: $e');
      return false;
    }
  }

  /// Get transactions for a specific date range for the current user.
  Future<List<Transaction>> getTransactionsBetween(
      DateTime start, DateTime end) async {
    const currentUserId = "_authService.currentUser?.id";

    final query = box
        .query(Transaction_.date
            .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch)
            .and(Transaction_.userId.equals(currentUserId))) // Filter by user
        .order(Transaction_.date, flags: Order.descending)
        .build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Get transactions based on filters for the current user.
  Future<List<Transaction>> getFiltered(FilterState filters) async {
    const currentUserId = "_authService.currentUser?.id";

    // Start with user ID condition
    Condition<Transaction> combinedCondition =
        Transaction_.userId.equals(currentUserId);

    // Apply Date Filter
    if (filters.startDate != null) {
      Condition<Transaction> dateCondition;
      if (filters.singleDay) {
        final startOfDay = DateTime(filters.startDate!.year,
            filters.startDate!.month, filters.startDate!.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        dateCondition = Transaction_.date
            .greaterOrEqual(startOfDay.millisecondsSinceEpoch)
            .and(Transaction_.date.lessThan(endOfDay.millisecondsSinceEpoch));
      } else {
        final rangeStart = filters.startDate!;
        final rangeEnd = filters.endDate?.add(const Duration(days: 1));
        dateCondition =
            Transaction_.date.greaterOrEqual(rangeStart.millisecondsSinceEpoch);
        if (rangeEnd != null) {
          dateCondition = dateCondition
              .and(Transaction_.date.lessThan(rangeEnd.millisecondsSinceEpoch));
        }
      }
      combinedCondition = combinedCondition.and(dateCondition);
    }

    // Apply Amount Filter
    if (filters.minAmount != null) {
      final minAmount = filters.minAmount!;
      final amountCondition = Transaction_.amount
          .greaterOrEqual(minAmount)
          .or(Transaction_.amount.lessOrEqual(-minAmount));
      combinedCondition = combinedCondition.and(amountCondition);
    }

    // Apply Income/Expense Filter (using amount sign)
    if (filters.isIncome != null) {
      Condition<Transaction> incomeCondition;
      if (filters.isIncome!) {
        incomeCondition = Transaction_.amount.greaterThan(0);
      } else {
        incomeCondition = Transaction_.amount.lessThan(0);
      }
      combinedCondition = combinedCondition.and(incomeCondition);
    }

    // Create the query builder with the combined condition
    final queryBuilder = box.query(combinedCondition);

    // Apply Link Filters (Account, Category)
    if (filters.selectedAccount != null) {
      queryBuilder.link(Transaction_.fromAccount,
          Account_.id.equals(filters.selectedAccount!.id));
    }
    if (filters.selectedCategories.isNotEmpty) {
      final categoryIds = filters.selectedCategories.map((c) => c.id).toList();
      queryBuilder.link(Transaction_.category, Category_.id.oneOf(categoryIds));
    }

    // Add sorting
    queryBuilder.order(Transaction_.date, flags: Order.descending);

    // Execute query
    final query = queryBuilder.build();
    final results = await query.findAsync();
    query.close();

    // Optional: Manually load relations if needed immediately
    // for (var tx in results) { tx.fromAccount.target; tx.category.target; }

    return results;
  }

  // Override remove to filter by user
  @override
  Future<bool> remove(int id) async {
    const currentUserId = "_authService.currentUser?.id";
    // Fetch the item first to ensure it belongs to the user
    final item = await getById(id); // getById is now user-filtered
    if (item != null) {
      // No need to check userId again, getById handles it
      final success = await super.remove(id);
      // Optional: Trigger immediate push delete
      // if (success) context.read<SyncService>().pushDelete('transactions', id);
      return success;
    } else {
      print(
          "Warn: Attempted to remove transaction $id not found or not belonging to user $currentUserId.");
      return false;
    }
  }

  // Override getById to filter by user
  @override
  Future<Transaction?> getById(int id) async {
    const currentUserId = "_authService.currentUser?.id";

    final query = box
        .query(Transaction_.id
            .equals(id)
            .and(Transaction_.userId.equals(currentUserId)))
        .build();
    final result = await query.findFirstAsync();
    query.close();
    // Optional: Load relations if needed
    // result?.category.target;
    // result?.fromAccount.target;
    return result;
  }

  // Be cautious with removeAll - ensure it ONLY removes for the current user
  Future<int> removeAllForCurrentUser() async {
    const currentUserId = "_authService.currentUser?.id";
    final query = box.query(Transaction_.userId.equals(currentUserId)).build();
    // Use removeAsync for efficiency
    final count = await query.removeAsync();
    query.close();
    print("Removed $count transactions for user $currentUserId.");
    return count;
  }
}
