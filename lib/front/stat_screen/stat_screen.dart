import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
import 'package:money_owl/front/transactions_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/transactions_screen/widgets/date_bar_widget.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';
import 'cubit/chart_cubit.dart';
import 'cubit/chart_state.dart';

class StatScreen extends StatelessWidget {
  const StatScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // No need to read initial state here, BlocBuilder will handle it

    return Scaffold(
      backgroundColor: AppStyle.backgroundColor, // Use AppStyle
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppStyle.paddingMedium), // Use AppStyle
          // Listen to AccountTransactionCubit for changes in displayedTransactions
          child: BlocBuilder<TransactionsCubit, TransactionsState>(
            builder: (context, accountTransactionState) {
              // Rebuild ChartCubit whenever displayedTransactions change
              return BlocProvider(
                // Use key to ensure BlocProvider rebuilds when transactions change
                key: ValueKey(accountTransactionState.displayedTransactions),
                create: (_) =>
                    ChartCubit(accountTransactionState.displayedTransactions),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Summary and Date bars remain the same, they listen to their own cubits
                    const SummaryBarWidget(),
                    const SizedBox(
                        height: AppStyle.paddingMedium), // Use AppStyle
                    const DateBarWidget(),
                    const SizedBox(
                        height: AppStyle.paddingMedium), // Use AppStyle

                    // Charts Section - listens to the ChartCubit provided above
                    Expanded(
                      child: BlocBuilder<ChartCubit, ChartState>(
                        builder: (context, chartState) {
                          // Check if there's data to display charts
                          final bool hasCategoryData = chartState
                                  .categoryData.isNotEmpty &&
                              chartState.categoryData.any((d) => d.amount != 0);
                          final bool hasBalanceData =
                              chartState.balanceData.isNotEmpty;

                          if (!hasCategoryData && !hasBalanceData) {
                            return const Center(
                              child: Text(
                                'No data available for charts in the selected period.',
                                style: AppStyle.bodyText,
                                textAlign: TextAlign.center,
                              ),
                            );
                          }

                          return SingleChildScrollView(
                            child: Column(
                              children: [
                                const SizedBox(height: AppStyle.paddingLarge),

                                // Pie Chart for Categories
                                if (hasCategoryData)
                                  _buildPieChart(context, chartState),
                                if (hasCategoryData && hasBalanceData)
                                  const SizedBox(
                                      height: AppStyle.paddingLarge *
                                          1.5), // More space between charts

                                // Line Chart for Balance Over Time
                                if (hasBalanceData)
                                  _buildLineChart(context, chartState),

                                const SizedBox(
                                    height: AppStyle
                                        .paddingMedium), // Padding at the bottom
                              ],
                            ),
                          );
                        },
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _buildPieChart(BuildContext context, ChartState chartState) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4, // Adjust height
      child: SfCircularChart(
        title: ChartTitle(
            text: 'Expenses by Category',
            textStyle: AppStyle.titleStyle), // Use AppStyle
        legend: Legend(
          isVisible: true,
          position: LegendPosition.bottom,
          textStyle: AppStyle.captionStyle, // Use AppStyle
        ),
        series: <CircularSeries>[
          PieSeries<ChartData, String>(
            dataSource: chartState.categoryData
                .where((d) => d.amount < 0) // Only show expenses
                .map((d) =>
                    ChartData(d.category, d.amount.abs())) // Use absolute value
                .toList(),
            xValueMapper: (data, _) => data.category,
            yValueMapper: (data, _) => data.amount,
            dataLabelSettings: DataLabelSettings(
              isVisible: true,
              showZeroValue: false,
              labelPosition: ChartDataLabelPosition.outside,
              textStyle: AppStyle.captionStyle
                  .copyWith(color: AppStyle.textColorPrimary), // Use AppStyle
              // Format label as percentage or value
              labelIntersectAction: LabelIntersectAction.shift,
              connectorLineSettings: const ConnectorLineSettings(
                type: ConnectorType.line,
                length: '10%',
              ),
            ),
            // Customize appearance
            pointColorMapper: (ChartData data, _) => _getColorForCategory(
                data.category, context), // Optional: Color mapping
            enableTooltip: true,
            explode: true, // Explode slices on tap
            explodeIndex: 0, // Explode the first slice initially (optional)
          ),
        ],
        tooltipBehavior: TooltipBehavior(
            enable: true, format: 'point.x: point.y'), // Tooltip format
      ),
    );
  }

  Widget _buildLineChart(BuildContext context, ChartState chartState) {
    return SizedBox(
      height: MediaQuery.of(context).size.height * 0.4, // Adjust height
      child: SfCartesianChart(
        title: ChartTitle(
            text: 'Balance Over Time',
            textStyle: AppStyle.titleStyle), // Use AppStyle
        legend: Legend(
          isVisible: false, // Legend might be redundant for a single series
        ),
        primaryXAxis: DateTimeAxis(
          dateFormat: DateFormat('MMM d'), // Format date axis labels
          intervalType: DateTimeIntervalType.auto, // Auto interval
          majorGridLines:
              const MajorGridLines(width: 0), // Hide vertical grid lines
          labelStyle: AppStyle.captionStyle, // Use AppStyle
        ),
        primaryYAxis: NumericAxis(
          title: AxisTitle(
              text: 'Balance',
              textStyle: AppStyle.captionStyle), // Use AppStyle
          numberFormat: NumberFormat.compactSimpleCurrency(
              decimalDigits: 0), // Format Y-axis labels
          labelStyle: AppStyle.captionStyle, // Use AppStyle
        ),
        series: <CartesianSeries<LineChartData, DateTime>>[
          SplineSeries<LineChartData, DateTime>(
            // Use SplineSeries for smoother curve
            name: 'Balance',
            dataSource: chartState.balanceData,
            xValueMapper: (data, _) => data.date,
            yValueMapper: (data, _) => data.balance,
            color: AppStyle.primaryColor, // Use AppStyle
            width: 2, // Line width
            markerSettings: const MarkerSettings(
                isVisible: true,
                shape: DataMarkerType.circle,
                height: 6,
                width: 6), // Smaller markers
            // dataLabelSettings: DataLabelSettings( // Labels might clutter the line chart
            //   isVisible: false,
            // ),
            enableTooltip: true,
          ),
        ],
        tooltipBehavior: TooltipBehavior(enable: true), // Enable tooltips
        trackballBehavior: TrackballBehavior(
          // Add trackball for better interaction
          enable: true,
          lineWidth: 1.5,
          lineColor: AppStyle.secondaryColor,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: const InteractiveTooltip(
            enable: true,
            format: 'point.x : point.y', // Tooltip format
          ),
        ),
      ),
    );
  }

  // Helper to get category color (optional, needs access to categories)
  Color _getColorForCategory(String categoryTitle, BuildContext context) {
    final categories =
        context.read<TransactionsCubit>().getEnabledCategoriesCache();
    Category category = categories.firstWhere(
      (cat) => cat.title == categoryTitle,
    );

    return category.color ?? AppStyle.accentColor; // Placeholder
  }
}
