import 'package:bloc/bloc.dart';
import 'package:pvp_projektas/models/Transaction.dart';
import 'package:pvp_projektas/ObjectBox.dart';

class TransactionCubit extends Cubit<TransactionState> {
  final ObjectBox objectbox;

  TransactionCubit(this.objectbox) : super(TransactionState(transactions: []));

  /*void loadTransactions() {
    emit(TransactionState(transactions: objectbox.transactionBox.GetAll));
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
  }*/
}
class TransactionState{
  final List<Transaction> transactions;

  TransactionState({
    required this.transactions
});
}

