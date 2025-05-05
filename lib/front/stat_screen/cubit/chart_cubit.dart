import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart'; // Import Account
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/services/currency_service.dart'; // Import CurrencyService
import 'package:money_owl/backend/utils/calculate_balances_utils.dart';
import 'package:money_owl/backend/utils/currency_utils.dart'; // Import CurrencyUtils
import 'package:money_owl/backend/utils/defaults.dart'; // Import Defaults
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import 'dart:math'; // Import for min/max

import 'chart_state.dart';

class ChartCubit extends Cubit<ChartState> {
  final List<Transaction> allTransactions;
  final List<Transaction> filteredTransactions;
  final FilterState filterState;

  ChartCubit({
    required this.allTransactions,
    required this.filteredTransactions,
    required this.filterState,
  }) : super(const ChartState()) {
    calculateChartData();
  }

  Future<void> calculateChartData() async {
    final balanceData = await _prepareBalanceData();
    final categoryData = _prepareCategoryData(filteredTransactions);

    emit(state.copyWith(
      categoryData: categoryData,
      balanceData: balanceData,
    ));
  }

  List<ChartData> _prepareCategoryData(List<Transaction> transactions) {
    final Map<String, double> categoryTotals = {};

    for (final transaction in transactions) {
      // --- ADD Null check and default value ---
      final category = transaction.category.target;
      final categoryTitle = category?.title ??
          'Uncategorized'; // Use default title if category is null
      // --- END ADD ---

      // Ensure amount is not null before adding
      final amountToAdd = transaction.amount ?? 0.0;

      // Use the safe categoryTitle
      categoryTotals.update(
        categoryTitle,
        (value) => value + amountToAdd,
        ifAbsent: () => amountToAdd,
      );
    }

    // Ensure amount in ChartData is never null
    return categoryTotals.entries
        .map((entry) => ChartData(entry.key,
            entry.value ?? 0.0)) // Default amount to 0.0 if somehow null
        .toList();
  }

  Future<List<LineChartData>> _prepareBalanceData() async {
    final List<LineChartData> balanceData = [];
    final Map<DateTime, double> dailyNetChangeConverted = {};

    // --- Basic Setup (Currency, Rates) ---
    final String targetCurrency =
        filterState.selectedAccount?.currency ?? Defaults().defaultCurrency;
    final Map<String, double> exchangeRates =
        await CurrencyService.fetchExchangeRates(Defaults().defaultCurrency);
    // --- End Basic Setup ---

    // --- 1. Determine Filter Dates ---
    DateTime? filterStartDate = filterState.startDate;
    DateTime? filterEndDate = filterState.endDate;
    // Normalize filter dates
    if (filterState.singleDay && filterStartDate != null) {
      filterStartDate = DateTime(
          filterStartDate.year, filterStartDate.month, filterStartDate.day);
      filterEndDate = filterStartDate;
    } else {
      if (filterStartDate != null) {
        filterStartDate = DateTime(
            filterStartDate.year, filterStartDate.month, filterStartDate.day);
      }
      if (filterEndDate != null) {
        filterEndDate = DateTime(
            filterEndDate.year, filterEndDate.month, filterEndDate.day);
      }
    }
    // --- End Filter Dates ---

    // --- 2. Determine Actual Transaction Range ---
    if (allTransactions.isEmpty) {
      return []; // No transactions, no chart
    }
    DateTime firstTransactionDate = allTransactions.last.date;
    DateTime lastTransactionDate = allTransactions.first.date;
    // Normalize transaction bounds
    firstTransactionDate = DateTime(firstTransactionDate.year,
        firstTransactionDate.month, firstTransactionDate.day);
    lastTransactionDate = DateTime(lastTransactionDate.year,
        lastTransactionDate.month, lastTransactionDate.day);
    // --- End Transaction Range ---

    // --- 3. Determine Effective Plot Range ---
    DateTime plotStartDate;
    DateTime plotEndDate;

    // Start Date: Use the later of filter start or first transaction date
    if (filterStartDate == null) {
      plotStartDate = firstTransactionDate;
    } else {
      plotStartDate = filterStartDate.isAfter(firstTransactionDate)
          ? filterStartDate
          : firstTransactionDate;
    }

    // End Date: Use the earlier of filter end or last transaction date
    if (filterEndDate == null) {
      plotEndDate = lastTransactionDate;
    } else {
      plotEndDate = filterEndDate.isBefore(lastTransactionDate)
          ? filterEndDate
          : lastTransactionDate;
    }

    // Validate Plot Range: If start is after end, the filter is outside the data range.
    if (plotStartDate.isAfter(plotEndDate)) {
      print(
          "Warning: Plot range is invalid (start date ${plotStartDate.toIso8601String()} is after end date ${plotEndDate.toIso8601String()}). Returning empty chart data.");
      return []; // Return empty list if range is invalid
    }
    // --- End Plot Range ---

    // --- 4. Calculate Starting Balance (Converted) for the Plot Range ---
    double runningBalanceConverted = 0;
    // Calculate balance based on transactions strictly BEFORE plotStartDate
    final transactionsBeforePlotStart = allTransactions.where((t) {
      bool accountMatch = filterState.selectedAccount == null ||
          t.fromAccount.targetId == filterState.selectedAccount!.id;
      return accountMatch && t.date.isBefore(plotStartDate);
    }).toList();
    final balanceBeforePlotStartByCurrency =
        CalculateBalancesUtils.calculateNetBalanceByCurrency(
            transactionsBeforePlotStart);
    for (final entry in balanceBeforePlotStartByCurrency.entries) {
      runningBalanceConverted += CurrencyUtils.convertAmount(
        entry.value,
        entry.key,
        targetCurrency,
        exchangeRates,
      );
    }
    // --- End Starting Balance ---

    // --- 5. Calculate Daily Changes within Plot Range ---
    // Use filteredTransactions as it already respects the broader filter dates
    for (final transaction in filteredTransactions) {
      final DateTime dateKey = DateTime(
          transaction.date.year, transaction.date.month, transaction.date.day);

      // Only consider transactions that fall ON or AFTER plotStartDate and ON or BEFORE plotEndDate
      if (!dateKey.isBefore(plotStartDate) && !dateKey.isAfter(plotEndDate)) {
        final String transactionCurrency =
            transaction.fromAccount.target?.currency ??
                Defaults().defaultCurrency;
        final double convertedAmount = CurrencyUtils.convertAmount(
            transaction.amount,
            transactionCurrency,
            targetCurrency,
            exchangeRates);

        dailyNetChangeConverted.update(
          dateKey,
          (value) => value + convertedAmount,
          ifAbsent: () => convertedAmount,
        );
      }
    }
    // --- End Daily Changes ---

    // --- 6. Prepare Points Map and Handle Empty Case ---
    final Map<DateTime, LineChartData> pointsMap = {
      // Initialize with the starting point
      plotStartDate: LineChartData(plotStartDate, runningBalanceConverted)
    };
    final sortedDates = dailyNetChangeConverted.keys.toList()..sort();

    // Check if there were any transactions *within* the plot range
    if (sortedDates.isEmpty) {
      // No transactions within the plot range. Add end point if different from start.
      if (plotStartDate != plotEndDate) {
        // Ensure the end point uses the starting balance as no changes occurred
        pointsMap[plotEndDate] =
            LineChartData(plotEndDate, runningBalanceConverted);
      }
      print(
          "Prepared Balance Data Points: ${pointsMap.length} (No transactions within plot range)");
    } else {
      // --- 7. Process Transactions if they exist within plot range ---
      DateTime lastProcessedDate = plotStartDate;
      // Use the starting balance calculated before the loop
      double currentLoopBalance = runningBalanceConverted;

      for (final date in sortedDates) {
        // Add point just before the change if there's a gap
        if (date.isAfter(lastProcessedDate) && !pointsMap.containsKey(date)) {
          pointsMap[date] = LineChartData(date, currentLoopBalance);
        }
        // Update balance with this date's changes
        currentLoopBalance += dailyNetChangeConverted[date]!;
        // Update/Add point for the date the change occurred
        pointsMap[date] = LineChartData(date, currentLoopBalance);
        lastProcessedDate = date;
      }

      // --- 8. Add/Update End Point after processing transactions ---
      // Use the final balance from the loop (currentLoopBalance)
      if (plotEndDate.isAfter(lastProcessedDate) &&
          !pointsMap.containsKey(plotEndDate)) {
        // If end date is after last transaction, add point with the last calculated balance
        pointsMap[plotEndDate] = LineChartData(plotEndDate, currentLoopBalance);
      } else if (pointsMap.containsKey(plotEndDate)) {
        // If end date exists (e.g., transaction on last day), ensure it has the final balance
        pointsMap[plotEndDate] = LineChartData(plotEndDate, currentLoopBalance);
      }
      print(
          "Prepared Balance Data Points: ${pointsMap.length} (Processed transactions within plot range)");
    }
    // --- End Processing ---

    // --- 9. Finalize Data ---
    balanceData.addAll(pointsMap.values);
    balanceData.sort((a, b) => a.date.compareTo(b.date));
    // Optional: Log points for debugging
    // print("Final Balance Data:");
    // balanceData.forEach((p) => print("  ${p.date.toIso8601String()}: ${p.balance}"));
    return balanceData;
    // --- End Finalize ---
  }
}
