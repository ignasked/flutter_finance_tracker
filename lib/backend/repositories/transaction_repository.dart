import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/transaction.dart';
import 'package:objectbox/objectbox.dart';
import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncSource
import 'package:money_owl/backend/models/account.dart'; // Import Account model for linking
import 'package:money_owl/backend/models/category.dart'; // Import Category model for linking

class TransactionRepository extends BaseRepository<Transaction> {
  TransactionRepository(Store store) : super(store);

  /// Factory method for asynchronous initialization
  static Future<TransactionRepository> create([Store? store]) async {
    final newStore = store ?? await BaseRepository.createStore();
    return TransactionRepository(newStore);
  }

  /// Get transactions modified after a specific time (UTC).
  Future<List<Transaction>> getAllModifiedSince(DateTime time) async {
    // Ensure comparison is done with UTC timestamps in the database
    final query = box
        .query(Transaction_.updatedAt > time.toUtc().millisecondsSinceEpoch)
        .build();
    // Use findAsync
    final results = await query.findAsync();
    query.close();
    // Note: Relations (account, category) are NOT automatically loaded by findAsync.
    // They will need to be loaded manually if required before sending to Supabase,
    // or handled by ensuring toJson sends only the IDs.
    return results;
  }

  /// Override put to update timestamps before saving.
  @override
  Future<int> put(Transaction transaction,
      {SyncSource syncSource = SyncSource.local}) async {
    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Transaction transactionToSave;
      if (transaction.id == 0) {
        transactionToSave =
            transaction.copyWith(createdAt: now, updatedAt: now);
      } else {
        transactionToSave = transaction.copyWith(updatedAt: now);
      }
      // Use await for the super call which is now async
      final savedId =
          await super.put(transactionToSave, syncSource: syncSource);
      // Optional: Trigger immediate push
      // syncService.pushUpsert('transactions', transactionToSave);
      return savedId;
    } else {
      // When syncing down from Supabase, ensure relations are linked correctly.
      // This might require fetching Account/Category based on IDs if not already linked.
      // Example (simplified - assumes target IDs are set in fromJson):
      if (transaction.fromAccount.targetId != null &&
          transaction.fromAccount.target == null) {
        // Fetch and link account if needed (requires AccountRepository access or passing Store)
        // transaction.account.target = await store.box<Account>().getAsync(transaction.account.targetId!);
      }
      if (transaction.category.targetId != null &&
          transaction.category.target == null) {
        // Fetch and link category if needed
        // transaction.category.target = await store.box<Category>().getAsync(transaction.category.targetId!);
      }
      // Use await for the super call which is now async
      return await super.put(transaction, syncSource: syncSource);
    }
  }

  /// Fetch all transactions and ensure relations are loaded
  @override
  Future<List<Transaction>> getAll() async {
    try {
      // Use await for the super call which is now async
      final transactions = await super.getAll();
      // Note: Accessing target here is synchronous lazy-loading.
      // For true async relation loading, consider ObjectBox queries with eager loading if needed.
      for (var transaction in transactions) {
        transaction.category
            .target; // Ensure the target is loaded (fixes lazy loading)
        transaction.fromAccount.target; // Ensure account target is loaded
      }
      return transactions;
    } catch (e) {
      print('Error fetching transactions: $e');
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

  /// Example: Get transactions for a specific date range (modify as needed)
  Future<List<Transaction>> getTransactionsBetween(
      DateTime start, DateTime end) async {
    final query = box
        .query(Transaction_.date
            .between(start.millisecondsSinceEpoch, end.millisecondsSinceEpoch))
        .order(Transaction_.date, flags: Order.descending)
        .build();
    // Use findAsync
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Get transactions based on filters, precisely matching the logic of the in-memory applyFilters.
  Future<List<Transaction>> getFiltered(FilterState filters) async {
    // 1. Build the combined condition for properties (Date, Amount, Income/Expense)
    Condition<Transaction>? propertyCondition;

    // Apply Date Filter
    if (filters.startDate != null) {
      Condition<Transaction> dateCondition;
      if (filters.singleDay) {
        final startOfDay = DateTime(filters.startDate!.year,
            filters.startDate!.month, filters.startDate!.day);
        final endOfDay =
            startOfDay.add(const Duration(days: 1)); // Start of next day
        // Condition: date >= startOfDay AND date < endOfDay
        dateCondition = Transaction_.date
            .greaterOrEqual(startOfDay.millisecondsSinceEpoch)
            .and(Transaction_.date.lessThan(endOfDay.millisecondsSinceEpoch));
      } else {
        final rangeStart = filters.startDate!;
        final rangeEnd = filters.endDate
            ?.add(const Duration(days: 1)); // Start of day after endDate

        // Condition: date >= rangeStart
        dateCondition =
            Transaction_.date.greaterOrEqual(rangeStart.millisecondsSinceEpoch);

        // Add condition: date < rangeEnd (if rangeEnd exists)
        if (rangeEnd != null) {
          dateCondition = dateCondition
              .and(Transaction_.date.lessThan(rangeEnd.millisecondsSinceEpoch));
        }
      }
      propertyCondition = dateCondition; // Initialize propertyCondition
    }

    // Apply Amount Filter (Absolute value >= minAmount)
    if (filters.minAmount != null) {
      final minAmount = filters.minAmount!;
      // Condition: (amount >= minAmount) OR (amount <= -minAmount)
      final amountCondition = Transaction_.amount
          .greaterOrEqual(minAmount)
          .or(Transaction_.amount.lessOrEqual(-minAmount));
      propertyCondition = (propertyCondition == null)
          ? amountCondition
          : propertyCondition.and(amountCondition);
    }

    // Apply Income/Expense Filter
    if (filters.isIncome != null) {
      // Query based on the sign of the amount, as isIncome is a getter
      Condition<Transaction> incomeCondition;
      if (filters.isIncome!) {
        // isIncome == true means amount > 0
        incomeCondition = Transaction_.amount.greaterThan(0);
      } else {
        // isIncome == false means amount < 0
        incomeCondition = Transaction_.amount.lessThan(0);
      }
      propertyCondition = (propertyCondition == null)
          ? incomeCondition
          : propertyCondition.and(incomeCondition);
    }

    // 2. Create the query builder with the combined property condition
    final queryBuilder =
        box.query(propertyCondition); // Pass the combined condition here

    // 3. Apply Link Filters (Account, Category)
    if (filters.selectedAccount != null) {
      queryBuilder.link(Transaction_.fromAccount,
          Account_.id.equals(filters.selectedAccount!.id));
    }

    if (filters.selectedCategories.isNotEmpty) {
      final categoryIds = filters.selectedCategories.map((c) => c.id).toList();
      queryBuilder.link(Transaction_.category, Category_.id.oneOf(categoryIds));
    }

    // 4. Add sorting (optional, but good practice)
    queryBuilder.order(Transaction_.date, flags: Order.descending);

    // 5. Execute query
    final query = queryBuilder.build();
    final results = await query.findAsync();
    query.close();

    // Relations might need manual loading after findAsync if accessed immediately
    // for (var tx in results) { tx.fromAccount.target; tx.category.target; }

    return results;
  }
}
