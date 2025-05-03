import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'chart_state.dart';

class ChartCubit extends Cubit<ChartState> {
  ChartCubit(List<Transaction> transactions) : super(const ChartState()) {
    calculateChartData(transactions);
  }

  void calculateChartData(List<Transaction> transactions) {
    emit(state.copyWith(
      categoryData: _prepareCategoryData(transactions),
      balanceData: _prepareBalanceData(transactions),
    ));
  }

  List<ChartData> _prepareCategoryData(List<Transaction> transactions) {
    final Map<String, double> categoryTotals = {};

    for (final transaction in transactions) {
      final category =
          transaction.category.target; // Access the related Category
      if (category != null) {
        // --- CORRECTED CATEGORY TOTAL CALCULATION ---
        // Simply add the transaction amount (positive for income, negative for expense)
        categoryTotals.update(
          category.title,
          (value) => value + transaction.amount,
          ifAbsent: () => transaction.amount,
        );
        // --- END CORRECTION ---
      }
    }

    return categoryTotals.entries
        .map((entry) => ChartData(entry.key, entry.value))
        .toList();
  }

  List<LineChartData> _prepareBalanceData(List<Transaction> transactions) {
    final Map<DateTime, double> dateTotals = {};
    double balance = 0;

    final sortedTransactions = List<Transaction>.from(transactions)
      ..sort((a, b) => a.date.compareTo(b.date));

    for (final transaction in sortedTransactions) {
      final DateTime date = DateTime(
        transaction.date.year,
        transaction.date.month,
        transaction.date.day,
      );

      // --- CORRECTED BALANCE CALCULATION ---
      // Amount is positive for income, negative for expense.
      // Simply add the amount to the running balance.
      balance += transaction.amount;
      // --- END CORRECTION ---

      dateTotals[date] = balance;
    }

    return dateTotals.entries
        .map((entry) => LineChartData(entry.key, entry.value))
        .toList();
  }
}
