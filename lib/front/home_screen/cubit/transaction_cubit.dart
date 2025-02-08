import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/cubit/transaction_form_cubit.dart';

class TransactionState extends Equatable {
  final List<Transaction> transactions;

  const TransactionState({this.transactions = const []});

  @override
  List<Object> get props => [transactions];

  TransactionState copyWith({List<Transaction>? transactions}) =>
      TransactionState(
        transactions: transactions ?? this.transactions,
      );
}

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository transRepository;

  TransactionCubit(this.transRepository)
      : super(const TransactionState(transactions: [])) {
    loadTransactions();
  }

  void loadTransactions() {
    final transactions = transRepository.getTransactions();
    emit(TransactionState(transactions: transactions));
  }

  /*void saveTransaction(Transaction transaction, int? index) {
    if(index != null){
      updateTransaction(transaction, index);
    }
    else{
      addTransaction(transaction);
    }
  }*/

  void addTransaction(Transaction transaction) {
    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.transactions);
    //add transaction to localArray
    transactionsList.add(transaction);
    transRepository.addTransaction(transaction);
    emit(state.copyWith(transactions: transactionsList));
  }

  void updateTransaction(Transaction transaction, int index) {
    if (index >= 0 && index < state.transactions.length) {
      //create local copy of transactions
      List<Transaction> transactionsList = List.from(state.transactions);
      transactionsList[index] = transaction;
      transRepository.updateTransaction(transaction);
      emit(state.copyWith(transactions: transactionsList));
    }
  }

  //delete transaction from all transactions and objectbox repository
  void deleteTransaction(int index) {
    if (index >= 0 && index < state.transactions.length) {
      //create local copy of transactions
      List<Transaction> transactionsList = List.from(state.transactions);
      int id = transactionsList[index].id;
      transactionsList.removeAt(index);

      transRepository.deleteTransaction(id);
      emit(state.copyWith(transactions: transactionsList));
    }
  }

  void handleTransactionFormResult(TransactionResult transactionFormResult) {
    switch (transactionFormResult.actionType) {
      case ActionType.addNew:
        addTransaction(transactionFormResult.transaction);
        break;
      case ActionType.edit:
        if(transactionFormResult.index == null) return;
          updateTransaction(transactionFormResult.transaction, transactionFormResult.index!);
        break;
      case ActionType.delete:
        deleteTransaction(transactionFormResult.index!);
        break;
    }
  }
}
