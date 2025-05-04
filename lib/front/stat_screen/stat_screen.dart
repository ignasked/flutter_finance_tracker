import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
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

// --- ADD ENUM FOR CHART VIEW ---
enum CategoryChartView { pie, list, bar }
// --- END ADD ---

class StatScreen extends StatefulWidget {
  const StatScreen({super.key});

  @override
  State<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends State<StatScreen> {
  Set<CategoryChartType> _selectedCategoryType = {CategoryChartType.expense};
  // --- ADD STATE FOR CHART VIEW ---
  CategoryChartView _categoryChartView = CategoryChartView.pie;
  // --- END ADD ---

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppStyle.paddingMedium), // Horizontal padding only
          child: BlocBuilder<DataManagementCubit, DataManagementState>(
            // Consider adding buildWhen if DataManagementState updates very frequently
            // buildWhen: (p, c) => p.filteredTransactions != c.filteredTransactions, // Example
            builder: (context, dataState) {
              // Generate a key based on transactions to force ChartCubit rebuild
              // Using hashCode might be more efficient than joining UUIDs if list is large
              final chartCubitKey =
                  ValueKey(dataState.filteredTransactions.hashCode);
              // final chartCubitKey = ValueKey(dataState.filteredTransactions.map((t) => t.uuid).join(','));

              return BlocProvider(
                key: chartCubitKey,
                create: (_) => ChartCubit(dataState.filteredTransactions),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // --- Fixed Top Section ---
                    // Add vertical padding here if needed, or let Summary/Date handle it
                    const Padding(
                      padding: EdgeInsets.only(
                          top: AppStyle.paddingMedium), // Add top padding
                      child: SummaryBarWidget(),
                    ),
                    const SizedBox(height: AppStyle.paddingSmall),
                    const DateBarWidget(),
                    const SizedBox(
                        height:
                            AppStyle.paddingSmall), // More space before charts

                    // --- Scrollable Chart Section ---
                    Expanded(
                      child: SingleChildScrollView(
                        // Add vertical padding for scrollable content
                        padding: const EdgeInsets.only(
                            bottom: AppStyle.paddingMedium),
                        child: BlocBuilder<ChartCubit, ChartState>(
                          builder: (context, chartState) {
                            final bool hasCategoryData = chartState.categoryData
                                .any((d) => d.amount != 0);
                            final bool hasBalanceData =
                                chartState.balanceData.isNotEmpty;
                            final bool hasAnyData =
                                hasCategoryData || hasBalanceData;

                            if (!hasAnyData) {
                              // Improved Empty State
                              return Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppStyle.paddingXLarge * 2),
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(Icons.analytics_outlined,
                                        size: 60,
                                        color: AppStyle.textColorSecondary
                                            .withOpacity(0.5)),
                                    const SizedBox(
                                        height: AppStyle.paddingMedium),
                                    const Text(
                                      'No Chart Data Available',
                                      style: AppStyle.titleStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(
                                        height: AppStyle.paddingSmall),
                                    Text(
                                      'Try adjusting the date range or add some transactions.',
                                      style: AppStyle.bodyText.copyWith(
                                          color: AppStyle.textColorSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              );
                            }

                            // Chart layout within the scrollable area
                            return Column(
                              children: [
                                // --- Balance Chart Card ---
                                if (hasBalanceData)
                                  _buildChartCard(
                                    context: context,
                                    title: 'Balance Over Time',
                                    // Optional: Add subtitle or info icon
                                    child: SizedBox(
                                      height:
                                          220, // Increased height for better view
                                      child: _buildBalanceLineChart(
                                          context, chartState),
                                    ),
                                  ),

                                if (hasBalanceData && hasCategoryData)
                                  const SizedBox(
                                      height: AppStyle
                                          .paddingMedium), // Consistent space

                                // --- Category Chart Card ---
                                if (hasCategoryData)
                                  _buildChartCard(
                                    context: context,
                                    // Title is handled inside _buildCategorySection now
                                    // title: 'Spending & Income',
                                    child: _buildCategorySection(
                                        context, chartState),
                                  ),
                              ],
                            );
                          },
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

  /// Helper to wrap charts in a consistent Card/Container style
  Widget _buildChartCard({
    required BuildContext context,
    String? title, // Make title optional
    Widget? titleWidget, // Allow custom title widget
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppStyle.paddingSmall), // Internal padding
      decoration: AppStyle.cardDecoration.copyWith(
        // Use card style from AppStyle
        color: AppStyle.cardColor, // Ensure background color
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (titleWidget != null) // Use custom title widget if provided
            Padding(
              padding: const EdgeInsets.only(
                  left: AppStyle.paddingSmall, bottom: AppStyle.paddingSmall),
              child: titleWidget,
            )
          else if (title != null) // Otherwise use text title
            Padding(
              padding: const EdgeInsets.only(
                  left: AppStyle.paddingSmall, bottom: AppStyle.paddingSmall),
              child: Text(title, style: AppStyle.titleStyle),
            ),
          child, // The chart itself
        ],
      ),
    );
  }

  // Section for Category Chart + Controls
  Widget _buildCategorySection(BuildContext context, ChartState chartState) {
    // Determine available data types
    final hasIncomeData = chartState.categoryData.any((d) => d.amount > 0);
    final hasExpenseData = chartState.categoryData.any((d) => d.amount < 0);

    // Build segments only for available data types
    List<ButtonSegment<CategoryChartType>> segments = [];
    if (hasExpenseData) {
      segments.add(const ButtonSegment<CategoryChartType>(
          value: CategoryChartType.expense,
          icon: Icon(Icons.arrow_downward, size: 18))); // Smaller icon
    }
    if (hasIncomeData) {
      segments.add(const ButtonSegment<CategoryChartType>(
          value: CategoryChartType.income,
          icon: Icon(Icons.arrow_upward, size: 18))); // Smaller icon
    }

    // Auto-switch selection if current type has no data but the other does
    CategoryChartType currentEffectiveType = _selectedCategoryType.first;
    if (segments.isNotEmpty) {
      // Only adjust if there's at least one valid segment
      if ((currentEffectiveType == CategoryChartType.expense &&
              !hasExpenseData &&
              hasIncomeData) ||
          (currentEffectiveType == CategoryChartType.income &&
              !hasIncomeData &&
              hasExpenseData)) {
        // Update the state *after* the build phase completes
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            // Ensure widget is still mounted
            setState(() {
              _selectedCategoryType = {
                segments.first.value
              }; // Select the first available type
            });
          }
        });
        // Use the newly selected type for the current build pass
        currentEffectiveType = segments.first.value;
      } else if (!segments.any((s) => s.value == currentEffectiveType)) {
        // Handle case where current selection is no longer valid at all
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedCategoryType = {segments.first.value};
            });
          }
        });
        currentEffectiveType = segments.first.value;
      }
    }

    final String chartTitle = currentEffectiveType == CategoryChartType.expense
        ? 'Expenses by Category'
        : 'Income by Source';

    // --- Prepare data source once ---
    final bool isExpense = currentEffectiveType == CategoryChartType.expense;
    final dataSource = chartState.categoryData
        // --- ADDED NULL CHECK for category ---
        .where((d) =>
            d.category != null && (isExpense ? d.amount < 0 : d.amount > 0))
        // --- Use ! on category now that it's guaranteed non-null ---
        .map((d) => ChartData(d.category!, d.amount.abs()))
        .where((d) => d.amount > 0.01) // Filter out negligible amounts
        .toList();
    dataSource.sort((a, b) => b.amount.compareTo(a.amount)); // Sort descending
    // --- End Prepare data source ---

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(
              left: AppStyle.paddingSmall, bottom: AppStyle.paddingSmall),
          child: Text(chartTitle, style: AppStyle.titleStyle),
        ),

        // --- Row for Toggles ---
        Padding(
          padding: const EdgeInsets.only(bottom: AppStyle.paddingMedium),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center, // Center toggles
            children: [
              // Income/Expense Toggle (only if choice exists)
              if (segments.length > 1)
                Flexible(
                  // Allow button to shrink if needed
                  child: _buildCategoryTypeSelector(context, segments),
                ),
              if (segments.length > 1)
                const SizedBox(
                    width: AppStyle.paddingMedium), // Space between toggles

              // Chart View Toggle (Pie/List/Bar)
              Flexible(
                // Allow button to shrink if needed
                child: _buildChartViewSelector(),
              ),
            ],
          ),
        ),
        // --- End Row for Toggles ---

        // --- Conditional Chart/List Area ---
        SizedBox(
          // Adjust height based on view? Or use a consistent height?
          // Using fixed height for now, might need adjustment for list view.
          height: 250,
          child: _buildCategoryView(
              context, chartState, currentEffectiveType, dataSource),
        ),
        // --- End Conditional Area ---
      ],
    );
  }

  // --- ADDED: Widget to build the current category view ---
  Widget _buildCategoryView(BuildContext context, ChartState chartState,
      CategoryChartType type, List<ChartData> dataSource) {
    if (dataSource.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(AppStyle.paddingMedium),
          child: Text(
            'No significant ${type == CategoryChartType.expense ? 'expense' : 'income'} data for this period.',
            style: AppStyle.captionStyle,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    switch (_categoryChartView) {
      case CategoryChartView.pie:
        // Pass the pre-filtered/sorted data source to avoid recalculation
        return _buildPieChart(context, chartState, type, dataSource);
      case CategoryChartView.list:
        return _buildCategoryList(context, dataSource, type);
      case CategoryChartView.bar:
        return _buildCategoryBarChart(context, dataSource, type);
    }
  }
  // --- END ADDED ---

  // --- ADDED: Category Type Selector (Income/Expense) ---
  Widget _buildCategoryTypeSelector(
      BuildContext context, List<ButtonSegment<CategoryChartType>> segments) {
    // Ensure segments is not empty before building
    if (segments.isEmpty) {
      return const SizedBox.shrink(); // Return empty if no segments available
    }

    return SegmentedButton<CategoryChartType>(
      segments: segments, // Use the dynamically generated segments
      selected: _selectedCategoryType, // Use the state variable for selection
      onSelectionChanged: (Set<CategoryChartType> newSelection) {
        // Update state only if a valid selection is made
        if (newSelection.isNotEmpty) {
          setState(() {
            _selectedCategoryType = newSelection;
            // Reset the chart view to default (e.g., pie) when switching type? Optional.
            // _categoryChartView = CategoryChartView.pie;
          });
        }
      },
      style: SegmentedButton.styleFrom(
        // Use AppStyle for consistency
        backgroundColor: AppStyle.cardColor, // Match card background
        foregroundColor: AppStyle.textColorSecondary, // Default text/icon color
        selectedForegroundColor:
            AppStyle.primaryColor, // Selected text/icon color
        selectedBackgroundColor: AppStyle.primaryColor
            .withOpacity(0.1), // Subtle background for selected
        // Adjust padding if needed
        padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.paddingSmall,
            vertical: AppStyle.paddingSmall / 2),
        textStyle: AppStyle.captionStyle, // Use caption style for labels
      ),
      showSelectedIcon: false, // Keep it clean, rely on background/text color
      multiSelectionEnabled: false, // Only one type selected at a time
    );
  }
  // --- END ADDED ---

  // --- ADDED: Chart View Selector ---
  Widget _buildChartViewSelector() {
    return SegmentedButton<CategoryChartView>(
      segments: const <ButtonSegment<CategoryChartView>>[
        ButtonSegment<CategoryChartView>(
            value: CategoryChartView.pie,
            icon: Icon(Icons.pie_chart, size: 18)),
        ButtonSegment<CategoryChartView>(
            value: CategoryChartView.list, icon: Icon(Icons.list, size: 18)),
        ButtonSegment<CategoryChartView>(
            value: CategoryChartView.bar,
            icon: Icon(Icons.bar_chart, size: 18)),
      ],
      selected: {_categoryChartView},
      onSelectionChanged: (Set<CategoryChartView> newSelection) {
        if (newSelection.isNotEmpty) {
          setState(() {
            _categoryChartView = newSelection.first;
          });
        }
      },
      style: SegmentedButton.styleFrom(
        // Simpler styling for view toggle
        selectedBackgroundColor: AppStyle.primaryColor.withOpacity(0.2),
        selectedForegroundColor: AppStyle.primaryColor,
        foregroundColor: AppStyle.textColorSecondary,
        textStyle:
            const TextStyle(fontSize: 0), // Hide default text if only icons
        padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.paddingSmall), // Adjust padding
      ),
      showSelectedIcon: false,
      multiSelectionEnabled: false,
    );
  }
  // --- END ADDED ---

  // Modify _buildPieChart to accept the dataSource
  Widget _buildPieChart(BuildContext context, ChartState chartState,
      CategoryChartType type, List<ChartData> dataSource) {
    // Keep the isEmpty check (although _buildCategoryView handles it too)
    if (dataSource.isEmpty) {
      // ... existing empty state ...
      print("PieChart: dataSource is empty."); // Add log
      // Return the empty state widget here as well for safety
      return Center(child: Text('No data for pie chart'));
    }

    // --- ADD LOGGING HERE ---
    print("PieChart DataSource Check:");
    for (var item in dataSource) {
      print("  Category: ${item.category}, Amount: ${item.amount}");
      if (item.category == null) {
        // Explicit null check just in case
        print("  *** ERROR: Found null category in dataSource! ***");
      }
    }
    // --- END LOGGING ---

    return SfCircularChart(
      // ... existing pie chart config ...
      series: <CircularSeries>[
        PieSeries<ChartData, String>(
          dataSource: dataSource, // Use passed-in data source
          xValueMapper: (ChartData data, _) =>
              data.category, // Assumes non-null
          yValueMapper: (ChartData data, _) => data.amount,
          pointColorMapper: (ChartData data, _) =>
              _getColorForCategory(data.category, context),
          // ... rest of PieSeries config ...
        ),
      ],
      // ... existing tooltipBehavior, margin ...
    );
  }

  // --- ADDED: Category List Builder ---
  Widget _buildCategoryList(BuildContext context, List<ChartData> dataSource,
      CategoryChartType type) {
    final currencyFormat = NumberFormat.simpleCurrency(
      name: Defaults().defaultCurrencySymbol,
      decimalDigits: 0,
    );
    final total = dataSource.fold<double>(0, (sum, item) => sum + item.amount);

    return ListView.builder(
      itemCount: dataSource.length,
      itemBuilder: (context, index) {
        final item = dataSource[index];
        final percentage = total > 0 ? (item.amount / total) * 100 : 0;
        final color = _getColorForCategory(item.category, context);

        return ListTile(
          dense: true, // Make list items more compact
          leading: Icon(Icons.circle, color: color, size: 12),
          title: Text(item.category, style: AppStyle.bodyText),
          trailing: Text(
            '${currencyFormat.format(item.amount)} (${percentage.toStringAsFixed(0)}%)',
            style: AppStyle.captionStyle
                .copyWith(color: AppStyle.textColorSecondary),
          ),
          // Optional: Add onTap for drill-down later
          // onTap: () { /* Handle tap */ },
        );
      },
    );
  }
  // --- END ADDED ---

  // --- ADDED: Category Bar Chart Builder ---
  Widget _buildCategoryBarChart(BuildContext context,
      List<ChartData> dataSource, CategoryChartType type) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        labelIntersectAction:
            AxisLabelIntersectAction.rotate45, // Rotate labels if they overlap
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactSimpleCurrency(decimalDigits: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        majorGridLines: MajorGridLines(
            width: 1, color: AppStyle.dividerColor.withOpacity(0.3)),
      ),
      series: <CartesianSeries<ChartData, String>>[
        ColumnSeries<ChartData, String>(
          dataSource: dataSource,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.amount,
          pointColorMapper: (ChartData data, _) =>
              _getColorForCategory(data.category, context),
          borderRadius: const BorderRadius.only(
            // Add slight rounding to bars
            topLeft: Radius.circular(AppStyle.borderRadiusSmall / 2),
            topRight: Radius.circular(AppStyle.borderRadiusSmall / 2),
          ),
          dataLabelSettings: DataLabelSettings(
              // Show value on top of bar
              isVisible: true,
              textStyle: AppStyle.captionStyle.copyWith(fontSize: 9),
              labelAlignment: ChartDataLabelAlignment.top,
              // Use builder for compact formatting if needed
              builder: (dynamic data, dynamic point, dynamic series,
                  int pointIndex, int seriesIndex) {
                final ChartData chartData = data as ChartData;
                // Only show label if amount is significant enough to avoid clutter
                if (chartData.amount < (dataSource.first.amount * 0.05))
                  return const SizedBox.shrink(); // Hide if < 5% of max
                return Text(
                  NumberFormat.compact().format(chartData.amount),
                  style: AppStyle.captionStyle.copyWith(
                      fontSize: 9, color: AppStyle.textColorSecondary),
                );
              }),
          enableTooltip: true,
        )
      ],
      tooltipBehavior: TooltipBehavior(
        // Simple tooltip for bar chart
        enable: true,
        textStyle:
            AppStyle.captionStyle.copyWith(color: ColorPalette.onPrimary),
        color: AppStyle.secondaryColor,
        canShowMarker: false,
        // Use builder for consistent formatting with pie chart
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
            int seriesIndex) {
          final ChartData chartData = data as ChartData;
          final String formattedValue = NumberFormat.simpleCurrency(
            name: Defaults().defaultCurrencySymbol,
            decimalDigits: 0,
          ).format(chartData.amount);
          return Container(
            padding: const EdgeInsets.all(AppStyle.paddingSmall / 2),
            decoration: BoxDecoration(
              color: AppStyle.secondaryColor,
              borderRadius: BorderRadius.circular(AppStyle.borderRadiusSmall),
            ),
            child: Text(
              '${chartData.category}: $formattedValue',
              style:
                  AppStyle.captionStyle.copyWith(color: ColorPalette.onPrimary),
            ),
          );
        },
      ),
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(top: 5, right: 5),
    );
  }
  // --- END ADDED ---

  // Updated Balance Line Chart Builder
  Widget _buildBalanceLineChart(BuildContext context, ChartState chartState) {
    double? axisMinimum;
    double? axisMaximum;
    if (chartState.balanceData.isNotEmpty) {
      double minBalance = chartState.balanceData.first.balance;
      double maxBalance = chartState.balanceData.first.balance;
      for (var data in chartState.balanceData) {
        if (data.balance < minBalance) minBalance = data.balance;
        if (data.balance > maxBalance) maxBalance = data.balance;
      }
      double range = maxBalance - minBalance;
      double padding = (range.abs() < 0.01)
          ? (maxBalance.abs() * 0.1).clamp(5.0, 100.0)
          : range * 0.15; // Increased padding %
      if (padding < 5.0 && range.abs() < 0.01 && maxBalance.abs() < 1)
        padding = 5.0; // Ensure min padding if balance is near 0
      axisMinimum = minBalance - padding;
      axisMaximum = maxBalance + padding;
    }

    final LinearGradient chartGradient = LinearGradient(
      colors: <Color>[
        AppStyle.primaryColor.withOpacity(0.3), // Slightly less intense start
        AppStyle.backgroundColor.withOpacity(0.0) // Fade fully to background
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return SfCartesianChart(
      // Removed title, handled by _buildChartCard
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('d MMM'), // Compact date format
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactSimpleCurrency(decimalDigits: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        majorGridLines: MajorGridLines(
            width: 1,
            color:
                AppStyle.dividerColor.withOpacity(0.3)), // Lighter grid lines
        minimum: axisMinimum,
        maximum: axisMaximum,
        // Opposed position can sometimes save space if X-axis labels are long
        // opposedPosition: true,
      ),
      series: <CartesianSeries<LineChartData, DateTime>>[
        SplineAreaSeries<LineChartData, DateTime>(
          // Using SplineAreaSeries
          name: 'Balance',
          splineType: SplineType.monotonic, // Smoother spline
          dataSource: chartState.balanceData,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.balance,
          gradient: chartGradient, // Apply gradient fill
          borderColor: AppStyle.primaryColor, // Line color
          borderWidth: 2.5, // Slightly thicker line
          markerSettings:
              const MarkerSettings(isVisible: false), // Hide markers on line
          enableTooltip: true,
        ),
      ],
      trackballBehavior: TrackballBehavior(
          enable: true,
          lineWidth: 1.5,
          lineColor: AppStyle.secondaryColor, // Trackball line color
          activationMode: ActivationMode.singleTap,
          tooltipSettings: InteractiveTooltip(
            enable: true,
            format: 'point.x : point.y', // Use format string
            textStyle:
                AppStyle.captionStyle.copyWith(color: ColorPalette.onPrimary),
            color:
                AppStyle.secondaryColor.withOpacity(0.9), // Darker tooltip bg
            borderColor: Colors.transparent, // No border around tooltip itself
            borderRadius: AppStyle.borderRadiusSmall, // Rounded corners
          ),
          markerSettings: const TrackballMarkerSettings(
              markerVisibility: TrackballVisibilityMode.visible,
              height: 8,
              width: 8,
              color: AppStyle.primaryColor,
              borderWidth: 2,
              borderColor: AppStyle.backgroundColor)),
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(top: 5, right: 5),
    );
  }

  // Helper to get category color (ensure access to categories)
  Color _getColorForCategory(String categoryTitle, BuildContext context) {
    // Access categories from DataManagementCubit's state
    try {
      // Use context.read inside build methods or helpers called directly from build
      // Be cautious if calling this from callbacks where context might be outdated
      final categories =
          context.read<DataManagementCubit>().state.allCategories;
      final category = categories.firstWhere(
        (cat) => cat.title == categoryTitle,
        // Provide orElse for safety if category might genuinely not exist
        orElse: () =>
            Defaults().defaultCategory, // Fallback to a default category
      );
      return category.color;
    } catch (e) {
      print("Error finding category '$categoryTitle': $e");
      return AppStyle.accentColor; // Fallback
    }
  }
}
