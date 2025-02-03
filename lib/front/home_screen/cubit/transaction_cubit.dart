import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';

class TransactionState extends Equatable{
  final List<Transaction> transactions;


  const TransactionState({
     this.transactions = const []
  });

  @override
  List<Object> get props => [transactions];

  TransactionState copyWith({
    List<Transaction>? transactions
  }) =>
      TransactionState(
        transactions: transactions ?? this.transactions,
      );
}

class TransactionCubit extends Cubit<TransactionState> {
  final TransactionRepository transRepository;

  TransactionCubit(this.transRepository) : super(const TransactionState(transactions: [])){
    loadTransactions();
  }

  void loadTransactions() {
    final transactions = transRepository.getTransactions();
    emit(TransactionState(transactions: transactions));
  }

  void addTransaction(Transaction transaction) {
    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.transactions);
    //add transaction to localArray
    transactionsList.add(transaction);
    transRepository.addTransaction(transaction);
    emit(state.copyWith(transactions: transactionsList));
    //loadTransactions(); // Reload transactions after adding
  }

  void updateTransaction(Transaction? transaction, int index) {
    if(transaction != null){
      //create local copy of transactions
      List<Transaction> transactionsList = List.from(state.transactions);
      transactionsList[index] = transaction;
      transRepository.updateTransaction(transaction);
      emit(state.copyWith(transactions: transactionsList));
    }
  }

  void deleteTransaction(int id, int index) {
    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.transactions);
    transactionsList.removeAt(index);

    transRepository.deleteTransaction(id);
    emit(state.copyWith(transactions: transactionsList));
  }
}


