import 'package:money_owl/backend/repositories/base_repository.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/transaction.dart';
import 'package:objectbox/objectbox.dart';
import 'package:money_owl/backend/services/sync_service.dart'; // Import SyncSource

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
      return await super.put(transaction, syncSource: syncSource);
    }
  }

  /// Fetch all transactions and ensure relations are loaded
  @override
  List<Transaction> getAll() {
    try {
      final transactions = super.getAll();
      for (var transaction in transactions) {
        transaction.category
            .target; // Ensure the target is loaded (fixes lazy loading)
      }
      return transactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  bool hasTransactionsForCategory(int categoryId) {
    try {
      // Fetch all transactions and check if any are associated with the category
      final transactions = box.getAll();
      return transactions
          .any((transaction) => transaction.category.targetId == categoryId);
    } catch (e) {
      print('Error checking transactions for category $categoryId: $e');
      return false;
    }
  }

  bool hasTransactionsForAccount(int accountId) {
    try {
      // Fetch all transactions and check if any are associated with the account
      final transactions = box.getAll();
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
    final results = await query.findAsync();
    query.close();
    return results;
  }
}
