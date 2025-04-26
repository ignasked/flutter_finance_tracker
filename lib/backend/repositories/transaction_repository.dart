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
        await openStore(directory: p.join(docsDir.path, "transactions_db"));
    return TransactionRepository._(store);
  }

  List<Transaction> getTransactions() {
    try {
      return _store.box<Transaction>().getAll();
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
      _store.box<Transaction>().put(transaction);
    } catch (e) {
      print('Error adding/updating transaction: $e');
    }
  }

  void updateTransaction(Transaction transaction) {
    _store.box<Transaction>().put(transaction);
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
