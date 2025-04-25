import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/transaction_repository/utils/transaction_utils.dart';
import 'chart_state.dart';

class ChartCubit extends Cubit<ChartState> {
  ChartCubit() : super(const ChartState());

  void calculateChartData(List<Transaction> transactions) {
    emit(state.copyWith(
      categoryData: _prepareCategoryData(transactions),
      balanceData: _prepareBalanceData(transactions),
    ));
  }

  List<ChartData> _prepareCategoryData(List<Transaction> transactions) {
    final Map<String, double> categoryTotals = {};

    for (String category in categories) {
      categoryTotals[category] = 0.0;
    }

    for (final transaction in transactions) {
      categoryTotals.update(
        transaction.category,
        (value) =>
            value + (transaction.amount * (transaction.isIncome ? 1 : -1)),
        ifAbsent: () => transaction.amount * (transaction.isIncome ? 1 : -1),
      );
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

      balance +=
          transaction.isIncome ? transaction.amount : -transaction.amount;
      dateTotals[date] = balance;
    }

    return dateTotals.entries
        .map((entry) => LineChartData(entry.key, entry.value))
        .toList();
  }
}
