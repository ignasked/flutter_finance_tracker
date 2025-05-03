import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/transactions_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/transactions_screen/widgets/date_bar_widget.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'cubit/chart_cubit.dart';
import 'cubit/chart_state.dart';
import 'package:flutter/foundation.dart'; // For listEquals

// Enum to manage category chart type
enum CategoryChartType { expense, income }

// Convert to StatefulWidget to manage SegmentedButton state
class StatScreen extends StatefulWidget {
  const StatScreen({super.key});

  @override
  State<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends State<StatScreen> {
  // State for the segmented button
  Set<CategoryChartType> _selectedCategoryType = {CategoryChartType.expense};

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppStyle.paddingMedium),
          child: BlocBuilder<DataManagementCubit, DataManagementState>(
            builder: (context, dataState) {
              final chartCubitKey = ValueKey(
                  dataState.filteredTransactions.map((t) => t.uuid).join(','));

              return BlocProvider(
                key: chartCubitKey,
                create: (_) => ChartCubit(dataState.filteredTransactions),
                // Main Column: Summary/Date fixed, Charts scrollable
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Fixed Top Section ---
                    const SummaryBarWidget(),
                    const SizedBox(height: AppStyle.paddingSmall),
                    const DateBarWidget(),
                    const SizedBox(height: AppStyle.paddingMedium),

                    // --- Scrollable Chart Section ---
                    Expanded(
                      child: Scrollbar(
                        child: SingleChildScrollView(
                          child: BlocBuilder<ChartCubit, ChartState>(
                            builder: (context, chartState) {
                              final bool hasAnyData = chartState.categoryData
                                      .any((d) => d.amount != 0) ||
                                  chartState.balanceData.isNotEmpty;

                              if (!hasAnyData) {
                                return const Center(
                                  child: Padding(
                                    padding: EdgeInsets.symmetric(
                                        vertical: AppStyle.paddingXLarge),
                                    child: Text(
                                      'No data available for charts in the selected period.',
                                      style: AppStyle.bodyText,
                                      textAlign: TextAlign.center,
                                    ),
                                  ),
                                );
                              }

                              // Chart layout within the scrollable area
                              return Column(
                                children: [
                                  // Top Part: Balance Chart (if data exists)
                                  if (chartState.balanceData.isNotEmpty)
                                    SizedBox(
                                      height: 300, // Adjust height as needed
                                      child:
                                          _buildLineChart(context, chartState),
                                    ),
                                  if (chartState.balanceData.isNotEmpty &&
                                      chartState.categoryData
                                          .any((d) => d.amount != 0))
                                    const SizedBox(
                                        height: AppStyle
                                            .paddingLarge), // Increased Space

                                  // Bottom Part: Category Section (if data exists)
                                  if (chartState.categoryData
                                      .any((d) => d.amount != 0))
                                    SizedBox(
                                      height: 350, // Adjust height as needed
                                      child: _buildCategorySection(
                                          context, chartState),
                                    ),
                                ],
                              );
                            },
                          ),
                        ),
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

  // Section for Category Chart + Controls
  Widget _buildCategorySection(BuildContext context, ChartState chartState) {
    final currentType = _selectedCategoryType.first;
    final hasIncomeData = chartState.categoryData.any((d) => d.amount > 0);
    final hasExpenseData = chartState.categoryData.any((d) => d.amount < 0);

    // Filter available segments based on data
    List<ButtonSegment<CategoryChartType>> segments = [];
    if (hasExpenseData) {
      segments.add(const ButtonSegment<CategoryChartType>(
          value: CategoryChartType.expense,
          label: Text('Expenses'),
          icon: Icon(Icons.arrow_downward)));
    }
    if (hasIncomeData) {
      segments.add(const ButtonSegment<CategoryChartType>(
          value: CategoryChartType.income,
          label: Text('Income'),
          icon: Icon(Icons.arrow_upward)));
    }

    // If the currently selected type has no data, switch to one that does
    if ((currentType == CategoryChartType.expense &&
            !hasExpenseData &&
            hasIncomeData) ||
        (currentType == CategoryChartType.income &&
            !hasIncomeData &&
            hasExpenseData)) {
      // Use WidgetsBinding.instance.addPostFrameCallback to avoid calling setState during build
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          // Check if the widget is still in the tree
          setState(() {
            _selectedCategoryType = {segments.first.value};
          });
        }
      });
    }

    return Column(
      children: [
        if (segments.length >
            1) // Only show selector if both income/expense data exist
          SegmentedButton<CategoryChartType>(
            segments: segments,
            selected: _selectedCategoryType,
            onSelectionChanged: (Set<CategoryChartType> newSelection) {
              // Ensure only one button is selected
              if (newSelection.isNotEmpty) {
                setState(() {
                  _selectedCategoryType = {newSelection.first};
                });
              }
            },
            style: SegmentedButton.styleFrom(
              // backgroundColor: AppStyle.cardColor,
              foregroundColor: AppStyle.accentColor,
              selectedForegroundColor:
                  AppStyle.primaryColor, // Use AppStyle.onPrimary
              selectedBackgroundColor: AppStyle.primaryColor,
            ),
            showSelectedIcon: false, // Keep UI clean
          ),
        if (segments.length > 1)
          const SizedBox(height: AppStyle.paddingSmall), // Space after buttons

        // Pie Chart Area
        SizedBox(
          height: 300, // Adjust height as needed
          child:
              _buildPieChart(context, chartState, _selectedCategoryType.first),
        ),
      ],
    );
  }

  // Updated Pie Chart Builder
  Widget _buildPieChart(
      BuildContext context, ChartState chartState, CategoryChartType type) {
    final bool isExpense = type == CategoryChartType.expense;
    final dataSource = chartState.categoryData
        .where((d) => isExpense ? d.amount < 0 : d.amount > 0)
        .map((d) => ChartData(d.category, d.amount.abs())) // Use absolute value
        .where((d) => d.amount > 0) // Ensure no zero values after abs()
        .toList();

    if (dataSource.isEmpty) {
      return Center(
        child: Text(
          'No ${isExpense ? 'expense' : 'income'} data for this period.',
          style: AppStyle.captionStyle,
        ),
      );
    }

    return SfCircularChart(
      title: ChartTitle(
          text: isExpense ? 'Expenses by Category' : 'Income by Source',
          textStyle:
              AppStyle.titleStyle.copyWith(fontSize: 16)), // Smaller title
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        textStyle: AppStyle.captionStyle,
        overflowMode: LegendItemOverflowMode.wrap, // Wrap if too many items
        // Reduce padding around legend items if needed
        itemPadding: 5,
      ),
      series: <CircularSeries>[
        PieSeries<ChartData, String>(
          dataSource: dataSource,
          xValueMapper: (data, _) => data.category,
          yValueMapper: (data, _) => data.amount,
          dataLabelSettings: DataLabelSettings(
              isVisible: true,
              showZeroValue: false,
              labelPosition: ChartDataLabelPosition.outside,
              textStyle: AppStyle.captionStyle.copyWith(
                  color: AppStyle.textColorPrimary,
                  fontSize: 10), // Smaller labels
              // Format label as percentage
              labelIntersectAction: LabelIntersectAction.shift, // Avoid overlap
              connectorLineSettings: const ConnectorLineSettings(
                type: ConnectorType.line,
                length: '8%', // Shorter connector
              ),
              // Use builder for custom label format (e.g., percentage)
              useSeriesColor: true, // Labels inherit series color
              builder: (dynamic data, dynamic point, dynamic series,
                  int pointIndex, int seriesIndex) {
                final ChartData chartData = data as ChartData;
                // Calculate percentage (requires total)
                // final double total = dataSource.fold(0, (sum, item) => sum + item.amount);
                // final double percentage = (chartData.amount / total) * 100;
                // return Text('${percentage.toStringAsFixed(1)}%', style: AppStyle.captionStyle.copyWith(fontSize: 10));
                // Or just show the value
                return Text(NumberFormat.compact().format(chartData.amount),
                    style: AppStyle.captionStyle.copyWith(
                        fontSize: 10, color: AppStyle.textColorPrimary));
              }),
          pointColorMapper: (ChartData data, _) =>
              _getColorForCategory(data.category, context),
          enableTooltip: true,
          // explode: true, // Exploding might take too much space
          // explodeIndex: 0,
          radius: '80%', // Adjust radius if needed
        ),
      ],
      tooltipBehavior: TooltipBehavior(
          enable: true,
          // CORRECTED: Use literal 'point.x' and 'point.y' placeholders
          format: 'point.x: point.y',
          // Apply currency formatting via numberFormat on the axis or use builder if needed
          textStyle: AppStyle.captionStyle),
      // Adjust margin if legend/labels overlap
      margin: const EdgeInsets.all(5),
    );
  }

  // Line Chart Builder (Enhanced with Manual Padding)
  Widget _buildLineChart(BuildContext context, ChartState chartState) {
    // --- Manual Axis Range Calculation ---
    double? axisMinimum;
    double? axisMaximum;

    if (chartState.balanceData.isNotEmpty) {
      // Find min and max balance values
      double minBalance = chartState.balanceData.first.balance;
      double maxBalance = chartState.balanceData.first.balance;
      for (var data in chartState.balanceData) {
        if (data.balance < minBalance) minBalance = data.balance;
        if (data.balance > maxBalance) maxBalance = data.balance;
      }

      // Calculate padding (e.g., 10% of the range, or a fixed amount if range is 0)
      double range = maxBalance - minBalance;
      double padding;
      if (range.abs() < 0.01) {
        // Handle zero or very small range
        padding = (maxBalance.abs() * 0.1)
            .clamp(1.0, 100.0); // 10% of value, min 1, max 100
        // Ensure padding is at least 1 if the value itself is 0
        if (padding < 1.0) padding = 1.0;
      } else {
        padding = range * 0.1; // 10% of the range
      }

      // Apply padding
      axisMinimum = minBalance - padding;
      axisMaximum = maxBalance + padding;

      // Optional: Round min/max for cleaner axis labels if desired
      // axisMinimum = (axisMinimum / 10).floor() * 10; // Example: round down to nearest 10
      // axisMaximum = (axisMaximum / 10).ceil() * 10; // Example: round up to nearest 10
    }
    // --- End Manual Axis Range Calculation ---

    // Define the gradient
    final LinearGradient chartGradient = LinearGradient(
      colors: <Color>[
        AppStyle.primaryColor
            .withOpacity(0.4), // Start with primary color (semi-transparent)
        AppStyle.primaryColor.withOpacity(0.1), // Fade to lighter
        AppStyle.backgroundColor.withOpacity(0.0) // Fade to background
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return SfCartesianChart(
      title: ChartTitle(
          text: 'Balance Over Time',
          textStyle: AppStyle.titleStyle.copyWith(fontSize: 16)),
      legend: Legend(isVisible: false),
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('MMM d'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines:
            const MajorGridLines(width: 0), // Hide vertical grid lines
        axisLine: const AxisLine(width: 0), // Hide X axis line
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        edgeLabelPlacement:
            EdgeLabelPlacement.shift, // Avoid labels overlapping edges
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactSimpleCurrency(decimalDigits: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        axisLine: const AxisLine(width: 0), // Hide Y axis line
        majorTickLines: const MajorTickLines(size: 0), // Hide Y axis ticks
        // Keep horizontal grid lines for reference
        majorGridLines: MajorGridLines(
            width: 1, color: AppStyle.dividerColor.withOpacity(0.5)),
        // --- Apply calculated min/max ---
        minimum: axisMinimum,
        maximum: axisMaximum,
        // --- End Apply calculated min/max ---
      ),
      series: <CartesianSeries<LineChartData, DateTime>>[
        // Use SplineAreaSeries for gradient fill
        SplineAreaSeries<LineChartData, DateTime>(
          name: 'Balance',
          dataSource: chartState.balanceData,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.balance,
          // Gradient fill
          gradient: chartGradient,
          // Line style
          borderColor: AppStyle.primaryColor,
          borderWidth: 2.5, // Slightly thicker line
          markerSettings: const MarkerSettings(
              isVisible: true,
              shape: DataMarkerType.circle,
              height: 6, // Slightly larger markers
              width: 6,
              color: AppStyle.primaryColor,
              borderColor: AppStyle
                  .backgroundColor, // Match background for 'hollow' effect
              borderWidth: 1.5),
          enableTooltip: true,
        ),
      ],
      tooltipBehavior: TooltipBehavior(
          enable: true,
          header: '',
          format: 'point.x : point.y',
          textStyle: AppStyle.captionStyle.copyWith(
              color:
                  AppStyle.backgroundColor), // Use onPrimary for tooltip text
          color: AppStyle
              .secondaryColor, // Use a darker color for tooltip background
          canShowMarker: false // Hide default tooltip marker
          ),
      trackballBehavior: TrackballBehavior(
          enable: true,
          lineWidth: 1.5,
          lineColor: AppStyle.secondaryColor,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: InteractiveTooltip(
            enable: true,
            format: 'point.x : point.y',
            textStyle: AppStyle.captionStyle
                .copyWith(color: AppStyle.primaryColor), // Use onPrimary
            color: AppStyle.secondaryColor, // Use darker color
            borderColor: Colors.transparent, // Hide border
            borderRadius: AppStyle.borderRadiusSmall,
          ),
          markerSettings: TrackballMarkerSettings(
              markerVisibility: TrackballVisibilityMode.visible,
              height: 8,
              width: 8,
              color: AppStyle.primaryColor,
              borderWidth: 1.5,
              borderColor: AppStyle.backgroundColor)),
      plotAreaBorderWidth: 0, // Remove plot area border
      margin: const EdgeInsets.only(
          top: 10, right: 10, bottom: 5), // Adjust margins
    );
  }

  // Helper to get category color
  Color _getColorForCategory(String categoryTitle, BuildContext context) {
    // Access categories directly from DataManagementCubit's state
    final categories = context.read<DataManagementCubit>().state.allCategories;
    try {
      // Find the category, even if disabled (it might have past transactions)
      final category = categories.firstWhere(
        (cat) => cat.title == categoryTitle,
      );
      return category.color; // Use the getter which handles the int value
    } catch (e) {
      // Fallback color if category not found (should ideally not happen if data is consistent)
      print("Warning: Category '$categoryTitle' not found for color mapping.");
      return AppStyle.accentColor;
    }
  }
}
