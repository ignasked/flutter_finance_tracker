import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/front/home_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/home_screen/widgets/date_bar_widget.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'cubit/chart_cubit.dart';
import 'cubit/chart_state.dart';

class StatScreen extends StatelessWidget {
  const StatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final selectedAccount =
        context.read<AccountTransactionCubit>().state.filters.selectedAccount;
    final transactions =
        context.read<AccountTransactionCubit>().state.displayedTransactions;

    return BlocProvider(
      create: (_) => ChartCubit(transactions),
      child: Scaffold(
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(18.0),
            child:
                BlocBuilder<AccountTransactionCubit, AccountTransactionState>(
              builder: (context, accountTransactionState) {
                return BlocBuilder<ChartCubit, ChartState>(
                  builder: (context, chartState) {
                    return Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Transaction Summary
                        const SummaryBarWidget(
                            // onFilterPressed: () => _showFilterOptions(context),
                            // onChangeAccountPressed: () =>
                            //     _showAccountSelectionDialog(context),
                            ),
                        const SizedBox(height: 10),

                        // Date Selector
                        const DateBarWidget(),
                        const SizedBox(height: 6),

                        // Charts Section
                        Expanded(
                          child: SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: 20),
                                // Pie Chart
                                if (chartState.categoryData.isNotEmpty)
                                  SizedBox(
                                    height: MediaQuery.of(context).size.height *
                                        0.4,
                                    child: SfCircularChart(
                                      title: ChartTitle(
                                          text: 'Transaction Summary'),
                                      legend: Legend(
                                        isVisible: true,
                                        position: LegendPosition.bottom,
                                      ),
                                      series: <CircularSeries>[
                                        PieSeries<ChartData, String>(
                                          dataSource: chartState.categoryData,
                                          xValueMapper: (data, _) =>
                                              data.category,
                                          yValueMapper: (data, _) =>
                                              data.amount,
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

                                // Line Chart
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

  void _showFilterOptions(BuildContext context) {
    // Show filter options logic
  }
}
