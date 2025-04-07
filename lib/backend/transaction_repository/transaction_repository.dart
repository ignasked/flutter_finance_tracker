import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:pvp_projektas/backend/models/transaction.dart';

class TransactionRepository {
  late final Store _store;

  TransactionRepository._(this._store);

  /// Initializes ObjectBox store
  static Future<TransactionRepository> create() async {
    final docsDir = await getApplicationDocumentsDirectory();
    final store = openStore(directory: p.join(docsDir.path, "transactions_db"));
    return TransactionRepository._(store);
  }

  List<Transaction> getTransactions() {
    return _store.box<Transaction>().getAll();
  }

  Transaction? getTransaction(int id) {
    return _store.box<Transaction>().get(id);
  }

  void addTransaction(Transaction transaction) {
    _store.box<Transaction>().put(transaction);
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
