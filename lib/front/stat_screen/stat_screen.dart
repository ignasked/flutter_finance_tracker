import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/front/home_screen/widgets/transaction_summary.dart';
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
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, state) {
              if (state.transactions.isEmpty) {
                return const Center(child: Text('No transactions available'));
              }

              final chartData = _prepareChartData(state.transactions);
              final lineChartData = _prepareLineChartData(state.transactions);

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: TransactionSummary(
                      onCalendarPressed: () => _showDateFilter(context),
                      onFilterPressed: () => _showFilterOptions(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Chart section inside SingleChildScrollView
                  Expanded(
                    flex: 6,
                    child: SingleChildScrollView(
                      child: Column(
                        children: [
                          const SizedBox(height: 20),

                          // Circular chart
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: SfCircularChart(
                              title: ChartTitle(text: 'Transaction Summary'),
                              legend: Legend(
                                isVisible: true,
                                position: LegendPosition.bottom,
                              ),
                              series: <CircularSeries>[
                                PieSeries<_ChartData, String>(
                                  dataSource: chartData,
                                  xValueMapper: (_ChartData data, _) =>
                                      data.category,
                                  yValueMapper: (_ChartData data, _) =>
                                      data.amount,
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    showZeroValue: false,
                                  ),
                                ),
                              ],
                            ),
                          ),

                          const SizedBox(height: 20),

                          // Line chart
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.4,
                            child: SfCartesianChart(
                              title: ChartTitle(text: 'Transaction Summary'),
                              legend: Legend(
                                isVisible: true,
                                position: LegendPosition.bottom,
                              ),
                              primaryXAxis: DateTimeAxis(
                                dateFormat: DateFormat('yyyy-MM-dd'),
                                intervalType: DateTimeIntervalType.months,
                                interval: 1,
                              ),
                              primaryYAxis: NumericAxis(
                                title: AxisTitle(text: 'Total Balance'),
                              ),
                              series: <CartesianSeries<_LinaChartData,
                                  DateTime>>[
                                LineSeries<_LinaChartData, DateTime>(
                                  name: 'Balance',
                                  dataSource: lineChartData,
                                  xValueMapper: (_LinaChartData data, _) =>
                                      data.date,
                                  yValueMapper: (_LinaChartData data, _) =>
                                      data.balance,
                                  markerSettings:
                                      const MarkerSettings(isVisible: true),
                                  dataLabelSettings: const DataLabelSettings(
                                    isVisible: true,
                                    showZeroValue: false,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  List<_ChartData> _prepareChartData(List<Transaction> transactions) {
    // <---- to cubit
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
        .map((entry) => _ChartData(entry.key, entry.value))
        .toList();
  }

  List<_LinaChartData> _prepareLineChartData(List<Transaction> transactions) {
    // <---- to cubit
    final Map<DateTime, double> dateTotals = {};
    double balance = 0;

    // Sort transactions by date
    transactions.sort((a, b) => a.date.compareTo(b.date));

    for (final transaction in transactions) {
      final DateTime date = DateTime(
          transaction.date.year, transaction.date.month, transaction.date.day);

      balance +=
          transaction.isIncome ? transaction.amount : -transaction.amount;
      dateTotals[date] = balance;
    }

    return dateTotals.entries
        .map((entry) => _LinaChartData(entry.key, entry.value))
        .toList();
  }

  // TODO: move out show filtering options
  void _showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true, // Allows full-height modal
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        List<String> categories = []; // Move inside the builder for persistence
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('Filter Transactions',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      setModalState(() {
                        // Updates state inside modal
                        categories.contains('Food')
                            ? categories.remove('Food')
                            : categories.add('Food');
                      });
                    },
                    child:
                        Text(categories.contains('Food') ? '+ Food' : 'Food'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setModalState(() {
                        categories.contains('Travel')
                            ? categories.remove('Travel')
                            : categories.add('Travel');
                      });
                    },
                    child: Text(
                        categories.contains('Travel') ? '+ Travel' : 'Travel'),
                  ),
                  ElevatedButton(
                    onPressed: () {
                      setModalState(() {
                        categories.contains('Salary')
                            ? categories.remove('Salary')
                            : categories.add('Salary');
                      });
                    },
                    child: Text(
                        categories.contains('Salary') ? '+ Salary' : 'Salary'),
                  ),
                  const SizedBox(height: 16),
                  ElevatedButton(
                    onPressed: () {
                      context.read<TransactionCubit>().loadTransactions();
                      if (categories.isNotEmpty) {
                        context
                            .read<TransactionCubit>()
                            .filterTransactions(categories: categories);
                      }
                      Navigator.pop(context);
                    },
                    child: const Text('Apply Filters'),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showDateFilter(BuildContext context) async {
    DateTimeRange? selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        // Default to last week
        end: DateTime.now(),
      ),
    );

    if (selectedRange != null) {
      context.read<TransactionCubit>().filterTransactions(
            startDate: selectedRange.start,
            endDate: selectedRange.end,
          );
    }
  }
}

class _ChartData {
  // <---- to state
  final String category;
  final double amount;

  _ChartData(this.category, this.amount);
}

class _LinaChartData {
  // <---- to state
  final DateTime date;
  final double balance;

  _LinaChartData(this.date, this.balance);
}
