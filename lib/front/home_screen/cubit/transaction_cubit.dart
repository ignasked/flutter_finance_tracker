import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/repositories/transaction_utils.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';

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

  // Load all transactions from ObjectBox
  void loadTransactions() {
    final transactions = transRepository.getTransactions();
// Force emit even if transactions are empty to trigger listeners
    emit(TransactionState(transactions: List.from(transactions)));
  }

  // Add a transaction
  void addTransaction(Transaction transaction) {
    List<Transaction> transactionsList = List.from(state.transactions);
    transactionsList.add(transaction);
    transRepository.addTransaction(transaction);
    emit(state.copyWith(transactions: transactionsList));
  }

  void addTransactions(List<Transaction> transactions) {
    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.transactions);
    transactionsList.addAll(transactions);
    //save to objectbox
    transRepository.addTransactions(transactions);
    emit(state.copyWith(transactions: transactionsList));
  }

//update transaction in all transactions and objectbox repository
  void updateTransaction(Transaction transaction, int index) {
    if (index >= 0 && index < state.transactions.length) {
      List<Transaction> transactionsList = List.from(state.transactions);
      transactionsList[index] = transaction;
      transRepository.updateTransaction(transaction);
      emit(state.copyWith(transactions: transactionsList));
    }
  }

  // Delete a transaction
  void deleteTransaction(int index) {
    if (index >= 0 && index < state.transactions.length) {
      List<Transaction> transactionsList = List.from(state.transactions);
      int id = transactionsList[index].id;
      transactionsList.removeAt(index);

      transRepository.deleteTransaction(id);
      emit(state.copyWith(transactions: transactionsList));
    }
  }

  void deleteAllTransactions() {
    transRepository.deleteAllTransactions();
    emit(state.copyWith(transactions: []));
  }

  // Receive result from transaction form screen and handle it
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

  // Filter transactions
  void filterTransactions({
    bool? isIncome,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    List<int>? categoryIds,
  }) {
    TransactionFilter filter = BaseTransactionFilter();

    if (startDate != null && endDate != null) {
      filter = DateFilterDecorator(
        startDate: startDate,
        endDate: endDate,
        nextFilter: filter,
      );
    }

    if (minAmount != null) {
      filter = AmountFilterDecorator(
        minAmount: minAmount,
        nextFilter: filter,
      );
    }

    if (isIncome != null) {
      filter = TypeFilterDecorator(
        isIncome: isIncome,
        nextFilter: filter,
      );
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      filter = CategoryFilterDecorator(
        categoryIds: categoryIds,
        nextFilter: filter,
      );
    }

    final filteredTransactions = filter.filter(state.transactions);
    emit(state.copyWith(transactions: filteredTransactions));
  }
}
