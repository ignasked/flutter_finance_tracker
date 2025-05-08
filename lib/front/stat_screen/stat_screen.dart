import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/common/loading_widget.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:money_owl/front/transactions_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/transactions_screen/widgets/date_bar_widget.dart';
import 'package:syncfusion_flutter_charts/charts.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'cubit/chart_cubit.dart';
import 'cubit/chart_state.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:flutter_markdown/flutter_markdown.dart';

// Enum to manage category chart type
enum CategoryChartType { expense, income }

// Enum to manage category chart view
enum CategoryChartView { pie, list, bar }

class StatScreen extends StatefulWidget {
  const StatScreen({super.key});

  @override
  State<StatScreen> createState() => _StatScreenState();
}

class _StatScreenState extends State<StatScreen> {
  Set<CategoryChartType> _selectedCategoryType = {CategoryChartType.expense};
  CategoryChartView _categoryChartView = CategoryChartView.pie;

  bool _isAiLoading = false;
  final TextEditingController _aiQueryController =
      TextEditingController(); // Controller for the text field

  @override
  void dispose() {
    _aiQueryController.dispose(); // Dispose the controller
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundColor,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(
              horizontal: AppStyle.paddingMedium), // Horizontal padding only
          child: BlocBuilder<DataManagementCubit, DataManagementState>(
            builder: (context, dataState) {
              // Get FilterState and Determine Currency Symbol
              final filterState = context.watch<FilterCubit>().state;
              final String currencySymbol =
                  filterState.selectedAccount?.currencySymbolOrCurrency ??
                      Defaults().defaultCurrencySymbol;

              final chartCubitKey = ValueKey(
                  '${dataState.filteredTransactions.hashCode}-${filterState.hashCode}'); // Include filterState in key

              return BlocProvider(
                key: chartCubitKey,
                create: (_) => ChartCubit(
                    allTransactions: dataState.allTransactions,
                    filteredTransactions: dataState.filteredTransactions,
                    filterState: filterState), // Pass current filterState
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Fixed Top Section
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

                    // Scrollable Chart Section
                    Expanded(
                      child: SingleChildScrollView(
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

                            if (!hasAnyData && !_isAiLoading) {
                              // Also check AI loading state
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
                                // Balance Chart Card
                                if (hasBalanceData)
                                  _buildChartCard(
                                    context: context,
                                    title: 'Balance Over Time',
                                    child: SizedBox(
                                      height: 220,
                                      child: _buildBalanceLineChart(
                                          context, chartState, currencySymbol),
                                    ),
                                  ),

                                if (hasBalanceData && hasCategoryData)
                                  const SizedBox(
                                      height: AppStyle.paddingMedium),

                                // Category Chart Card
                                if (hasCategoryData)
                                  _buildChartCard(
                                    context: context,
                                    child: _buildCategorySection(
                                        context, chartState, currencySymbol),
                                  ),

                                if (hasAnyData ||
                                    _isAiLoading) // Show AI card if there's data or AI is processing
                                  const SizedBox(
                                      height: AppStyle.paddingMedium),
                                _buildAiAnalysisCard(context, dataState),
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

  /// Helper to wrap charts in a consistent Card/Container style.
  Widget _buildChartCard({
    required BuildContext context,
    String? title, // Optional title for the chart card
    Widget? titleWidget, // Allow a custom widget for the title area
    required Widget child,
  }) {
    return Container(
      padding: const EdgeInsets.all(
          AppStyle.paddingSmall), // Internal padding for content
      decoration: AppStyle.cardDecoration.copyWith(
        // Use card style from AppStyle
        color: AppStyle.cardColor, // Ensure background color for the card
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
  Widget _buildCategorySection(
      BuildContext context, ChartState chartState, String currencySymbol) {
    final hasIncomeData = chartState.categoryData.any((d) => d.amount > 0);
    final hasExpenseData = chartState.categoryData.any((d) => d.amount < 0);

    List<ButtonSegment<CategoryChartType>> segments = [];
    if (hasExpenseData) {
      segments.add(const ButtonSegment<CategoryChartType>(
          value: CategoryChartType.expense,
          icon: Icon(Icons.arrow_upward, size: 18)));
    }
    if (hasIncomeData) {
      segments.add(const ButtonSegment<CategoryChartType>(
          value: CategoryChartType.income,
          icon: Icon(Icons.arrow_downward, size: 18)));
    }

    CategoryChartType currentEffectiveType = _selectedCategoryType.first;
    if (segments.isNotEmpty) {
      if ((currentEffectiveType == CategoryChartType.expense &&
              !hasExpenseData &&
              hasIncomeData) ||
          (currentEffectiveType == CategoryChartType.income &&
              !hasIncomeData &&
              hasExpenseData)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            setState(() {
              _selectedCategoryType = {segments.first.value};
            });
          }
        });
        currentEffectiveType = segments.first.value;
      } else if (!segments.any((s) => s.value == currentEffectiveType)) {
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

    final bool isExpense = currentEffectiveType == CategoryChartType.expense;
    final dataSource = chartState.categoryData
        .where((d) => (isExpense ? d.amount < 0 : d.amount > 0))
        .map((d) => ChartData(d.category, d.amount.abs()))
        .where((d) => d.amount > 0.01)
        .toList();
    dataSource.sort((a, b) => b.amount.compareTo(a.amount));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Title
        Padding(
          padding: const EdgeInsets.only(
              left: AppStyle.paddingSmall, bottom: AppStyle.paddingSmall),
          child: Text(chartTitle, style: AppStyle.titleStyle),
        ),

        // Row for Toggles
        Padding(
          padding: const EdgeInsets.only(bottom: AppStyle.paddingMedium),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (segments.length > 1)
                Flexible(
                  child: _buildCategoryTypeSelector(context, segments),
                ),
              if (segments.length > 1)
                const SizedBox(width: AppStyle.paddingMedium),
              Flexible(
                child: _buildChartViewSelector(),
              ),
            ],
          ),
        ),

        // Conditional Chart/List Area
        SizedBox(
          height: 320, // Increased from 280
          child: _buildCategoryView(context, chartState, currentEffectiveType,
              dataSource, currencySymbol),
        ),
      ],
    );
  }

  Widget _buildCategoryView(
      BuildContext context,
      ChartState chartState,
      CategoryChartType type,
      List<ChartData> dataSource,
      String currencySymbol) {
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
        return _buildPieChart(
            context, chartState, type, dataSource, currencySymbol);
      case CategoryChartView.list:
        return _buildCategoryList(context, dataSource, type, currencySymbol);
      case CategoryChartView.bar:
        return _buildCategoryBarChart(
            context, dataSource, type, currencySymbol);
    }
  }

  Widget _buildCategoryTypeSelector(
      BuildContext context, List<ButtonSegment<CategoryChartType>> segments) {
    if (segments.isEmpty) {
      return const SizedBox.shrink();
    }

    return SegmentedButton<CategoryChartType>(
      segments: segments,
      selected: _selectedCategoryType,
      onSelectionChanged: (Set<CategoryChartType> newSelection) {
        if (newSelection.isNotEmpty) {
          setState(() {
            _selectedCategoryType = newSelection;
          });
        }
      },
      style: SegmentedButton.styleFrom(
        backgroundColor: AppStyle.cardColor,
        foregroundColor: AppStyle.textColorSecondary,
        selectedForegroundColor: AppStyle.primaryColor,
        selectedBackgroundColor: AppStyle.primaryColor.withOpacity(0.1),
        padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.paddingSmall,
            vertical: AppStyle.paddingSmall / 2),
        textStyle: AppStyle.captionStyle,
      ),
      showSelectedIcon: false,
      multiSelectionEnabled: false,
    );
  }

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
        selectedBackgroundColor: AppStyle.primaryColor.withOpacity(0.2),
        selectedForegroundColor: AppStyle.primaryColor,
        foregroundColor: AppStyle.textColorSecondary,
        textStyle: const TextStyle(fontSize: 0),
        padding: const EdgeInsets.symmetric(horizontal: AppStyle.paddingSmall),
      ),
      showSelectedIcon: false,
      multiSelectionEnabled: false,
    );
  }

  Widget _buildPieChart(
      BuildContext context,
      ChartState chartState,
      CategoryChartType type,
      List<ChartData> dataSource,
      String currencySymbol) {
    if (dataSource.isEmpty) {
      return const Center(child: Text('No data for pie chart'));
    }

    final SelectionBehavior selectionBehavior = SelectionBehavior(
      enable: true,
      selectedColor: AppStyle.primaryColor,
      selectedOpacity: 0.8,
      unselectedOpacity: 1.0,
    );

    final currencyFormat = NumberFormat.simpleCurrency(
      name: currencySymbol,
      decimalDigits: 0,
    );

    return SfCircularChart(
      selectionGesture: ActivationMode.singleTap,
      tooltipBehavior: TooltipBehavior(
        enable: true,
        activationMode: ActivationMode.singleTap,
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
            int seriesIndex) {
          if (data is ChartData) {
            final String formattedAmount = currencyFormat.format(data.amount);
            return Container(
              padding: const EdgeInsets.all(AppStyle.paddingSmall / 1.5),
              decoration: BoxDecoration(
                color: AppStyle.secondaryColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppStyle.borderRadiusSmall),
              ),
              child: Text(
                '${data.category}: $formattedAmount',
                style: AppStyle.captionStyle
                    .copyWith(color: ColorPalette.onPrimary),
              ),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      legend: Legend(
        isVisible: true,
        position: LegendPosition.bottom,
        overflowMode: LegendItemOverflowMode.scroll,
        itemPadding: AppStyle.paddingSmall / 2,
        legendItemBuilder:
            (String name, dynamic series, dynamic point, int index) {
          if (index >= 0 && index < dataSource.length) {
            final ChartData data = dataSource[index];
            final style = _getCategoryStyle(data.category, context);

            return Container(
              padding: const EdgeInsets.symmetric(
                  vertical: AppStyle.paddingSmall * 0.75,
                  horizontal: AppStyle.paddingSmall),
              child: Icon(
                  IconData(style.iconCodePoint, fontFamily: 'MaterialIcons'),
                  color: style.color,
                  size: 24),
            );
          }
          return const SizedBox.shrink();
        },
      ),
      series: <CircularSeries>[
        PieSeries<ChartData, String>(
          dataSource: dataSource,
          xValueMapper: (ChartData data, _) => data.category,
          yValueMapper: (ChartData data, _) => data.amount,
          pointColorMapper: (ChartData data, _) =>
              _getCategoryStyle(data.category, context).color,
          selectionBehavior: selectionBehavior,
          dataLabelSettings: const DataLabelSettings(
            isVisible: false,
          ),
          radius: '70%',
          enableTooltip: true,
        ),
      ],
      margin: const EdgeInsets.all(0),
    );
  }

  Widget _buildCategoryList(BuildContext context, List<ChartData> dataSource,
      CategoryChartType type, String currencySymbol) {
    final currencyFormat = NumberFormat.simpleCurrency(
      name: currencySymbol,
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
          dense: true,
          leading: Icon(Icons.circle, color: color, size: 12),
          title: Text(item.category, style: AppStyle.bodyText),
          trailing: Text(
            '${currencyFormat.format(item.amount)} (${percentage.toStringAsFixed(0)}%)',
            style: AppStyle.captionStyle
                .copyWith(color: AppStyle.textColorSecondary),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBarChart(
      BuildContext context,
      List<ChartData> dataSource,
      CategoryChartType type,
      String currencySymbol) {
    return SfCartesianChart(
      primaryXAxis: CategoryAxis(
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        labelIntersectAction: AxisLabelIntersectAction.rotate90,
        interval: 1,
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactSimpleCurrency(
            name: currencySymbol, decimalDigits: 0),
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
          width: 0.9, // Make bars wider to increase tappable area
          borderRadius: const BorderRadius.only(
            topLeft: Radius.circular(AppStyle.borderRadiusSmall / 2),
            topRight: Radius.circular(AppStyle.borderRadiusSmall / 2),
          ),
          dataLabelSettings: const DataLabelSettings(
            isVisible: false,
          ),
          enableTooltip: true,
        )
      ],
      tooltipBehavior: TooltipBehavior(
        enable: true,
        builder: (dynamic data, dynamic point, dynamic series, int pointIndex,
            int seriesIndex) {
          if (data is ChartData) {
            final currencyFormat = NumberFormat.simpleCurrency(
                name: currencySymbol, decimalDigits: 0);
            final String formattedAmount = currencyFormat.format(data.amount);
            return Container(
              padding: const EdgeInsets.all(AppStyle.paddingSmall / 1.5),
              decoration: BoxDecoration(
                color: AppStyle.secondaryColor.withOpacity(0.9),
                borderRadius: BorderRadius.circular(AppStyle.borderRadiusSmall),
              ),
              child: Text(
                '${data.category}: $formattedAmount',
                style: AppStyle.captionStyle
                    .copyWith(color: ColorPalette.onPrimary),
              ),
            );
          }
          return const SizedBox.shrink();
        },
        canShowMarker: false,
      ),
      plotAreaBorderWidth: 0,
      margin: const EdgeInsets.only(top: 5, right: 5),
    );
  }

  Widget _buildBalanceLineChart(
      BuildContext context, ChartState chartState, String currencySymbol) {
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
          : range * 0.15;
      if (padding < 5.0 && range.abs() < 0.01 && maxBalance.abs() < 1) {
        padding = 5.0;
      }
      axisMinimum = minBalance - padding;
      axisMaximum = maxBalance + padding;
    }

    final LinearGradient chartGradient = LinearGradient(
      colors: <Color>[
        AppStyle.primaryColor.withOpacity(0.3),
        AppStyle.backgroundColor.withOpacity(0.0)
      ],
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
    );

    return SfCartesianChart(
      primaryXAxis: DateTimeAxis(
        dateFormat: DateFormat('d MMM'),
        intervalType: DateTimeIntervalType.auto,
        majorGridLines: const MajorGridLines(width: 0),
        axisLine: const AxisLine(width: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        edgeLabelPlacement: EdgeLabelPlacement.shift,
      ),
      primaryYAxis: NumericAxis(
        numberFormat: NumberFormat.compactSimpleCurrency(
            name: currencySymbol, decimalDigits: 0),
        labelStyle: AppStyle.captionStyle.copyWith(fontSize: 10),
        axisLine: const AxisLine(width: 0),
        majorTickLines: const MajorTickLines(size: 0),
        majorGridLines: MajorGridLines(
            width: 1, color: AppStyle.dividerColor.withOpacity(0.3)),
        minimum: axisMinimum,
        maximum: axisMaximum,
      ),
      series: <CartesianSeries<LineChartData, DateTime>>[
        SplineAreaSeries<LineChartData, DateTime>(
          name: 'Balance',
          splineType: SplineType.monotonic,
          dataSource: chartState.balanceData,
          xValueMapper: (data, _) => data.date,
          yValueMapper: (data, _) => data.balance,
          gradient: chartGradient,
          borderColor: AppStyle.primaryColor,
          borderWidth: 2.5,
          markerSettings: const MarkerSettings(isVisible: false),
          enableTooltip: true,
        ),
      ],
      trackballBehavior: TrackballBehavior(
          enable: true,
          lineWidth: 1.5,
          lineColor: AppStyle.secondaryColor,
          activationMode: ActivationMode.singleTap,
          tooltipSettings: InteractiveTooltip(
            enable: true,
            format: 'point.x : point.y',
            decimalPlaces: 0,
            textStyle:
                AppStyle.captionStyle.copyWith(color: ColorPalette.onError),
            color: AppStyle.secondaryColor.withOpacity(0.9),
            borderColor: Colors.transparent,
            borderRadius: AppStyle.borderRadiusSmall,
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

  ({Color color, int iconCodePoint}) _getCategoryStyle(
      String categoryTitle, BuildContext context) {
    try {
      final categories =
          context.read<DataManagementCubit>().state.allCategories;
      final category = categories.firstWhere(
        (cat) => cat.title == categoryTitle,
        orElse: () => Defaults().defaultCategory, // Fallback
      );
      return (color: category.color, iconCodePoint: category.iconCodePoint);
    } catch (e) {
      print("Error finding category style for '$categoryTitle': $e");
      // Return default style on error
      return (
        color: AppStyle.accentColor,
        iconCodePoint: Defaults().defaultCategory.iconCodePoint
      );
    }
  }

  Color _getColorForCategory(String categoryTitle, BuildContext context) {
    try {
      final categories =
          context.read<DataManagementCubit>().state.allCategories;
      final category = categories.firstWhere(
        (cat) => cat.title == categoryTitle,
        orElse: () => Defaults().defaultCategory, // Fallback
      );
      return category.color;
    } catch (e) {
      print("Error finding category '$categoryTitle': $e");
      return AppStyle.accentColor; // Fallback
    }
  }

  Widget _buildAiAnalysisCard(
      BuildContext context, DataManagementState dataState) {
    return _buildChartCard(
      context: context,
      title: 'AI Financial Analysis',
      child: Padding(
        padding: const EdgeInsets.symmetric(
            vertical: AppStyle.paddingSmall), // Add padding
        child: Column(
          children: [
            TextField(
              controller: _aiQueryController,
              decoration: AppStyle.getInputDecoration(
                labelText: 'Ask a question about this data (optional)',
                helperText: 'e.g., Where did I spend the most?',
              ),
              style: AppStyle.bodyText,
              maxLines: 2, // Allow a couple of lines
              minLines: 1,
            ),
            const SizedBox(height: AppStyle.paddingMedium),
            ElevatedButton.icon(
              icon: _isAiLoading
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: ColorPalette.onPrimary,
                      ),
                    )
                  : const Icon(Icons.insights, color: ColorPalette.onPrimary),
              label: Text(_isAiLoading ? 'Analyzing...' : 'Get Analysis'),
              style: AppStyle.primaryButtonStyle,
              onPressed: _isAiLoading
                  ? null
                  : () => _showFinancialAnalysis(context, dataState,
                      _aiQueryController.text), // Pass the query
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showFinancialAnalysis(BuildContext context,
      DataManagementState dataState, String userQuery) async {
    if (!mounted) return;

    final transactions = dataState.filteredTransactions;
    final filterState =
        context.read<FilterCubit>().state; // Get current filters

    if (transactions.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No transactions found for analysis.'),
          backgroundColor: AppStyle.warningColor,
        ),
      );
      return;
    }

    final Map<String, double> categorySpending = {};
    for (final transaction in transactions) {
      final categoryTitle =
          transaction.category.target?.title ?? 'Uncategorized';
      final amount =
          transaction.amount.abs(); // Use absolute value for spending
      categorySpending.update(
        categoryTitle,
        (value) => value + amount,
        ifAbsent: () => amount,
      );
    }

    final currencyFormat = NumberFormat.simpleCurrency(
      name: filterState.selectedAccount?.currencySymbolOrCurrency ??
          Defaults().defaultCurrencySymbol,
      decimalDigits: 2,
    );
    final anonymizedDataString = categorySpending.entries
        .where((entry) => entry.value > 0.01)
        .map((entry) => '${entry.key}: ${currencyFormat.format(entry.value)}')
        .join('\n');

    final DateFormat dateFormat = DateFormat('MMM d, yyyy');
    String dateRangeString = 'for the selected period';
    if (filterState.startDate != null && filterState.endDate != null) {
      if (filterState.singleDay) {
        dateRangeString = 'on ${dateFormat.format(filterState.startDate!)}';
      } else {
        dateRangeString =
            'from ${dateFormat.format(filterState.startDate!)} to ${dateFormat.format(filterState.endDate!)}';
      }
    } else if (filterState.startDate != null) {
      dateRangeString =
          'from ${dateFormat.format(filterState.startDate!)} onwards';
    } else if (filterState.endDate != null) {
      dateRangeString = 'up to ${dateFormat.format(filterState.endDate!)}';
    }

    if (anonymizedDataString.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              'No significant spending data found for analysis in the selected period.'),
          backgroundColor: AppStyle.linkColor,
        ),
      );
      return;
    }

    setState(() {
      _isAiLoading = true;
    });

    showLoadingPopup(context, message: 'Generating AI analysis...');

    try {
      final analysis = await MistralService.instance.provideFinancialAnalysis(
        anonymizedDataString,
        userQuery.trim(),
        dateRangeString,
      );

      if (!mounted) return;
      hideLoadingPopup(context);

      await showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppStyle.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
          title: const Row(
            children: [
              Icon(Icons.insights, color: AppStyle.primaryColor),
              SizedBox(width: AppStyle.paddingSmall),
              Text('Financial Analysis', style: AppStyle.heading2),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: MarkdownBody(
                data: analysis,
                styleSheet: MarkdownStyleSheet(
                  p: AppStyle.bodyText,
                  h1: AppStyle.heading1,
                  h2: AppStyle.heading2,
                  h3: AppStyle.titleStyle,
                  listBullet: AppStyle.bodyText,
                  code: AppStyle.captionStyle.copyWith(
                    backgroundColor: AppStyle.dividerColor.withOpacity(0.1),
                  ),
                  codeblockDecoration: BoxDecoration(
                    color: AppStyle.dividerColor.withOpacity(0.1),
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusSmall),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: AppStyle.textButtonStyle,
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      hideLoadingPopup(context);
      print("Error getting AI analysis: $e");
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error generating analysis: $e',
              style: AppStyle.bodyText.copyWith(color: ColorPalette.onError)),
          backgroundColor: ColorPalette.errorContainer,
        ),
      );
    } finally {
      if (mounted) {
        setState(() {
          _isAiLoading = false;
        });
      }
    }
  }
}
