import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';

class TransactionSummaryState extends Equatable {
  final double balance;
  final double income;
  final double expenses;

  const TransactionSummaryState({
    this.balance = 0.0,
    this.income = 0.0,
    this.expenses = 0.0,
  });

  @override
  List<Object> get props => [balance, income, expenses];
}

class TransactionSummaryCubit extends Cubit<TransactionSummaryState> {
  TransactionSummaryCubit() : super(const TransactionSummaryState());

  void calculateSummary(List<Transaction> transactions) {
    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        totalIncome += transaction.amount;
      } else {
        totalExpenses += transaction.amount;
      }
    }

    emit(TransactionSummaryState(
      balance: totalIncome - totalExpenses,
      income: totalIncome,
      expenses: totalExpenses,
    ));
  }
}
