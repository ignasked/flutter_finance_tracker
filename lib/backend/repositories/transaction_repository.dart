import 'package:money_owl/backend/repositories/base_repository.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/transaction.dart';

class TransactionRepository extends BaseRepository<Transaction> {
  TransactionRepository(Store store) : super(store);

  /// Factory method for asynchronous initialization
  static Future<TransactionRepository> create([Store? store]) async {
    final newStore = store ?? await BaseRepository.createStore();
    return TransactionRepository(newStore);
  }

  @override
  void put(Transaction transaction) {
    try {
      transaction.category.attach(store); // Attach the category relation
      transaction.account.attach(store); // Attach the account relation

      super.put(transaction); // Call the base method to save the transaction
    } catch (e) {
      print('Error adding/updating transaction: $e');
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
}
