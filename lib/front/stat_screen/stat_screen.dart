import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/utils/transaction_utils.dart';
import 'package:intl/intl.dart';

class StatScreen extends StatelessWidget {
  const StatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Statistics'),
      ),
      body: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, state) {
          if (state.transactions.isEmpty) {
            return const Center(child: Text('No transactions available'));
          }

          final chartData = _prepareChartData(state.transactions);
          final lineChartData = _prepareLineChartData(state.transactions);

          return SingleChildScrollView(
            child: Column(
              children: [
                const SizedBox(height: 20),
                SizedBox(
                  height: 400,
                  child: SfCircularChart(
                    title: ChartTitle(text: 'Transaction Summary'),
                    legend: Legend(isVisible: true, position: LegendPosition.bottom),
                    series: <CircularSeries>[
                      PieSeries<_ChartData, String>(
                        dataSource: chartData,
                        xValueMapper: (_ChartData data, _) => data.category,
                        yValueMapper: (_ChartData data, _) => data.amount,
                        dataLabelSettings: const DataLabelSettings(isVisible: true, showZeroValue: false),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20), // Add spacing at the bottom
                SizedBox(
                  height: 400,
                  child: SfCartesianChart(
                    title: ChartTitle(text: 'Transaction Summary'),
                    legend: Legend(isVisible: true, position: LegendPosition.bottom),
                    primaryXAxis: DateTimeAxis(dateFormat: DateFormat('yyyy-MM-dd'), intervalType: DateTimeIntervalType.months, interval: 1),
                    primaryYAxis: NumericAxis(title: AxisTitle(text: 'Total Balance')),
                    series: <CartesianSeries<_LinaChartData, DateTime>>[
                      LineSeries<_LinaChartData, DateTime>(
                        name: 'Balance',
                        dataSource: lineChartData,
                        xValueMapper: (_LinaChartData data, _) => data.date,
                        yValueMapper: (_LinaChartData data, _) => data.balance,
                        markerSettings: const MarkerSettings(isVisible: true),
                        dataLabelSettings: const DataLabelSettings(isVisible: true, showZeroValue: false),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }



  List<_ChartData> _prepareChartData(List<Transaction> transactions) {
    final Map<String, double> categoryTotals = {};

    for(String category in categories) {
      categoryTotals[category] = 0.0;
    }

    for (final transaction in transactions) {
      categoryTotals.update(
        transaction.category,
        (value) => value + (transaction.amount * (transaction.isIncome ? 1 : -1)),
        ifAbsent: () => transaction.amount * (transaction.isIncome ? 1 : -1),
      );
    }

    return categoryTotals.entries
        .map((entry) => _ChartData(entry.key, entry.value))
        .toList();
  }

  List<_LinaChartData> _prepareLineChartData(List<Transaction> transactions){
    final Map<DateTime, double> dateTotals = {};
    double balance = 0;

    // Sort transactions by date
    transactions.sort((a, b) => a.date.compareTo(b.date));

    for (final transaction in transactions) {
      final DateTime date = DateTime(transaction.date.year, transaction.date.month, transaction.date.day);

      balance += transaction.isIncome ? transaction.amount : -transaction.amount;
      dateTotals[date] = balance;
    }

    return dateTotals.entries
        .map((entry) => _LinaChartData(entry.key, entry.value))
        .toList();
  }
}

class _ChartData {
  final String category;
  final double amount;

  _ChartData(this.category, this.amount);
}

class _LinaChartData{
  final DateTime date;
  final double balance;

  _LinaChartData(this.date, this.balance);
}


