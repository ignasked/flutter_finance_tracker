import 'package:equatable/equatable.dart';

class TransactionSummaryState extends Equatable {
  final double totalIncome; // Net income in period
  final double totalExpenses; // Net expenses in period
  final double balance; // Absolute balance at end of period (CHANGED MEANING)

  String get totalIncomeString => totalIncome.toStringAsFixed(0);
  String get totalExpensesString => totalExpenses.toStringAsFixed(0);
  String get balanceString =>
      balance.toStringAsFixed(0); // Now represents absolute ending balance

  const TransactionSummaryState({
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
    this.balance = 0.0, // Default for absolute ending balance
  });

  TransactionSummaryState copyWith({
    double? totalIncome,
    double? totalExpenses,
    double? balance, // This now copies the absolute ending balance
  }) {
    return TransactionSummaryState(
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      balance: balance ?? this.balance, // Assigns absolute ending balance
    );
  }

  @override
  List<Object?> get props => [
        totalIncome,
        totalExpenses,
        balance,
      ];
}
