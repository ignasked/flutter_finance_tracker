import 'package:equatable/equatable.dart';

class TransactionSummaryState extends Equatable {
  final double totalIncome;
  final double totalExpenses;
  final double balance;
  String get totalIncomeString => totalIncome.toStringAsFixed(2);
  String get totalExpensesString => totalExpenses.toStringAsFixed(2);
  String get balanceString => balance.toStringAsFixed(2);

  const TransactionSummaryState({
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
    this.balance = 0.0,
  });

  TransactionSummaryState copyWith({
    double? totalIncome,
    double? totalExpenses,
    double? balance,
  }) {
    return TransactionSummaryState(
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      balance: balance ?? this.balance,
    );
  }

  @override
  List<Object?> get props => [totalIncome, totalExpenses, balance];
}
