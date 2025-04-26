import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/transaction.dart';

class TransactionRepository {
  late final Store _store;

  TransactionRepository._(this._store);

  /// Initializes ObjectBox store
  static Future<TransactionRepository> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store =
        await openStore(directory: p.join(docsDir.path, "finance_tracker_db"));
    return TransactionRepository._(store);
  }

  /// Get the ObjectBox store
  Store get store {
    return _store;
  }

  List<Transaction> getTransactions() {
    try {
      final transactions = _store.box<Transaction>().getAll();

      for (var transaction in transactions) {
        transaction.category.target; // This ensures the target is loaded
      }

      return transactions;
    } catch (e) {
      print('Error fetching transactions: $e');
      return [];
    }
  }

  Transaction? getTransaction(int id) {
    return _store.box<Transaction>().get(id);
  }

  void addTransaction(Transaction transaction) {
    try {
      // Attach the transaction to the store
      transaction.category.attach(_store);

      _store.box<Transaction>().put(transaction);
    } catch (e) {
      print('Error adding transaction: $e');
    }
  }

  void updateTransaction(Transaction transaction) {
    try {
      // Attach the transaction to the store
      transaction.category.attach(_store);

      print(
          'Category Target ID Before Saving: ${transaction.category.targetId}');

      _store.box<Transaction>().put(transaction);
    } catch (e) {
      print('Error updating transaction: $e');
    }
  }

  void deleteTransaction(int id) {
    _store.box<Transaction>().remove(id);
  }

  void deleteAllTransactions() {
    _store.box<Transaction>().removeAll();
  }

  void addTransactions(List<Transaction> transactions) {
    print("Adding transactions: ${transactions.length}");

    _store.box<Transaction>().putMany(transactions);
  }
}
