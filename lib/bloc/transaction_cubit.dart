import 'package:bloc/bloc.dart';
import 'package:pvp_projektas/models/Transaction.dart';
import 'package:pvp_projektas/ObjectBox.dart';

class TransactionCubit extends Cubit<List<Transaction>> {
  final ObjectBox objectbox;

  TransactionCubit(this.objectbox) : super([]) {
    loadTransactions();
  }

  void loadTransactions() {
    final transactions = objectbox.store.box<Transaction>().getAll();

    emit(transactions);
  }

  void addTransaction(Transaction transaction) {
    objectbox.store.box<Transaction>().put(transaction);
    loadTransactions(); // Reload transactions after adding
  }

  void updateTransaction(Transaction transaction) {
    objectbox.store.box<Transaction>().put(transaction);
    loadTransactions(); // Reload transactions after updating
  }

  void deleteTransaction(int id) {
    objectbox.store.box<Transaction>().remove(id);
    loadTransactions(); // Reload transactions after deleting
  }
}
