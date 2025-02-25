import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/backend/transaction_repository/utils/transaction_utils.dart';
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

  //load all transactions from objectbox
  void loadTransactions() {
    final transactions = transRepository.getTransactions();
    emit(TransactionState(transactions: transactions));
  }

  //add transaction to all transactions and objectbox repository
  void addTransaction(Transaction transaction) {
    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.transactions);
    transactionsList.add(transaction);
    //save to objectbox
    transRepository.addTransaction(transaction);
    emit(state.copyWith(transactions: transactionsList));
  }

  //update transaction in all transactions and objectbox repository
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

  //recieve result from transaction form screen and handle it
  void handleTransactionFormResult(TransactionResult transactionFormResult) {
    switch (transactionFormResult.actionType) {
      case ActionType.addNew:
        addTransaction(transactionFormResult.transaction);
        break;
      case ActionType.edit:
        if (transactionFormResult.index == null) return;
        updateTransaction(
            transactionFormResult.transaction, transactionFormResult.index!);
        break;
      case ActionType.delete:
        deleteTransaction(transactionFormResult.index!);
        break;
    }
  }

  void filterTransactions({bool? isIncome, DateTime? startDate, DateTime? endDate, double? minAmount}) {
    List<Transaction> filteredTransactions = List.from(state.transactions);



    if (startDate != null && endDate != null) {
      filteredTransactions = DateFilterDecorator(startDate: startDate, endDate: endDate).filter(filteredTransactions);
    }

    if (minAmount != null) {
      filteredTransactions = AmountFilterDecorator(minAmount: minAmount).filter(filteredTransactions);
    }

    if (isIncome != null) {
      filteredTransactions = TypeFilterDecorator(isIncome: isIncome).filter(filteredTransactions);
    }

    filteredTransactions = List.from(filteredTransactions.reversed);

    emit(state.copyWith(transactions: filteredTransactions));
  }
}




