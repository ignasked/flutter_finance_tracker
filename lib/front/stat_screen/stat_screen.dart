import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_summary.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_filter.dart'
    as filter;
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_cubit.dart';
import 'package:intl/intl.dart';
import 'cubit/chart_cubit.dart';
import 'cubit/chart_state.dart';

class StatScreen extends StatelessWidget {
  const StatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ChartCubit(),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: BlocBuilder<TransactionCubit, TransactionState>(
              builder: (context, transactionState) {
                if (transactionState.transactions.isEmpty) {
                  return const Center(child: Text('No transactions available'));
                }

                // Update chart data when transactions change
                context
                    .read<ChartCubit>()
                    .calculateChartData(transactionState.transactions);

                return BlocBuilder<ChartCubit, ChartState>(
                  builder: (context, chartState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          flex: 1,
                          child: TransactionSummary(
                            onCalendarPressed: () =>
                                filter.TransactionFilter.showDateFilter(
                                    context),
                            onFilterPressed: () =>
                                filter.TransactionFilter.showFilterOptions(
                                    context),
                          ),
                        ),
                        const SizedBox(height: 20),
                        Expanded(
                          flex: 6,
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: SfCircularChart(
                                    title:
                                        ChartTitle(text: 'Transaction Summary'),
                                    legend: Legend(
                                      isVisible: true,
                                      position: LegendPosition.bottom,
                                    ),
                                    series: <CircularSeries>[
                                      PieSeries<ChartData, String>(
                                        dataSource: chartState.categoryData,
                                        xValueMapper: (data, _) =>
                                            data.category,
                                        yValueMapper: (data, _) => data.amount,
                                        dataLabelSettings:
                                            const DataLabelSettings(
                                          isVisible: true,
                                          showZeroValue: false,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 20),
                                SizedBox(
                                  height:
                                      MediaQuery.of(context).size.height * 0.4,
                                  child: SfCartesianChart(
                                    title:
                                        ChartTitle(text: 'Transaction Summary'),
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
                                    series: <CartesianSeries<LineChartData,
                                        DateTime>>[
                                      LineSeries<LineChartData, DateTime>(
                                        name: 'Balance',
                                        dataSource: chartState.balanceData,
                                        xValueMapper: (data, _) => data.date,
                                        yValueMapper: (data, _) => data.balance,
                                        markerSettings: const MarkerSettings(
                                            isVisible: true),
                                        dataLabelSettings:
                                            const DataLabelSettings(
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
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
