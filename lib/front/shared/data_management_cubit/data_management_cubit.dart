import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart'; // Import material for Color/IconData if needed by ViewModel
import 'package:intl/intl.dart'; // Import intl for DateFormat if needed by ViewModel mapping

import 'package:bloc/bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/services/currency_service.dart';
import 'package:money_owl/backend/utils/calculate_balances_utils.dart';
import 'package:money_owl/backend/utils/currency_utils.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/transactions_screen/cubit/transaction_summary_state.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart'; // Import FilterCubit
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:money_owl/front/transactions_screen/viewmodel/transaction_viewmodel.dart';
import 'package:money_owl/main.dart'; // Import FilterState

part 'data_management_state.dart'; // Updated part directive

class DataManagementCubit extends Cubit<DataManagementState> {
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final FilterCubit _filterCubit; // Inject FilterCubit
  late StreamSubscription<FilterState>
      _filterSubscription; // Listener for filter changes

  DataManagementCubit(
    this._transactionRepository,
    this._accountRepository,
    this._categoryRepository,
    this._filterCubit, // Accept FilterCubit
  ) : super(const DataManagementState()) {
    _loadInitialData();

    // Listen to filter changes
    _filterSubscription = _filterCubit.stream.listen((filterState) {
      _applyFiltersCache(filterState); // Apply filters when FilterCubit updates
    });
  }

  Future<void> refreshData() async {
    _loadInitialData();
  }

  Future<void> _loadInitialData() async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final accounts = await _accountRepository.getAll();
      final categories = await _categoryRepository.getAll();
      final transactions = await _transactionRepository.getAll();

      emit(state.copyWith(
        allAccounts: accounts,
        allCategories: categories,
        allTransactions: transactions,
        status: LoadingStatus.success, // Set status before applying filters
      ));
      // Apply initial filters from FilterCubit
      _applyFiltersCache(_filterCubit.state);
      _applySortByDateCache();
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  List<Category> getEnabledCategoriesCache() {
    return state.allCategories.where((category) => category.isEnabled).toList();
  }

  List<Account> getEnabledAccountsCache() {
    return state.allAccounts.where((acc) => acc.isEnabled).toList();
  }

  // --- REFACTORED _applyFiltersCache ---
  void _applyFiltersCache(FilterState filterState) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    List<Transaction> filteredRaw = List.from(state.allTransactions);

    // --- Apply filters to raw data (filteredRaw) ---

    // Apply Account Filter (Use targetId)
    if (filterState.selectedAccount != null) {
      filteredRaw = filteredRaw
          .where((t) =>
              t.fromAccount.targetId ==
              filterState.selectedAccount!.id) // Use targetId
          .toList();
    }

    // Apply Category Filter (Use targetId)
    if (filterState.selectedCategories.isNotEmpty) {
      final categoryIds =
          filterState.selectedCategories.map((c) => c.id).toSet();
      filteredRaw = filteredRaw
          .where(
              (t) => categoryIds.contains(t.category.targetId)) // Use targetId
          .toList();
    }

    // Apply Date Filter (logic remains the same, applied to filteredRaw)
    if (filterState.startDate != null) {
      if (filterState.singleDay) {
        // Filter for a single day (ignore time part)
        final startOfDay = DateTime(filterState.startDate!.year,
            filterState.startDate!.month, filterState.startDate!.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        filteredRaw = filteredRaw
            .where((t) =>
                t.date.isAtSameMomentAs(startOfDay) ||
                (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)))
            .toList();
      } else {
        // Filter for a date range (inclusive start, exclusive end for end date)
        final rangeStart = filterState.startDate!;
        final rangeEnd = filterState.endDate?.add(const Duration(
            days:
                1)); // Add 1 day to make endDate inclusive for filtering purposes

        filteredRaw = filteredRaw.where((t) {
          final transactionDate = t.date;
          bool afterStart = transactionDate.isAtSameMomentAs(rangeStart) ||
              transactionDate.isAfter(rangeStart);
          bool beforeEnd =
              rangeEnd == null || transactionDate.isBefore(rangeEnd);
          return afterStart && beforeEnd;
        }).toList();
      }
    }

    // Apply Amount Filter (Optional, applied to filteredRaw)
    if (filterState.minAmount != null) {
      filteredRaw = filteredRaw
          .where((t) => t.amount.abs() >= filterState.minAmount!)
          .toList();
    }

    // Apply Income/Expense Filter (Optional, applied to filteredRaw)
    if (filterState.isIncome != null) {
      filteredRaw =
          filteredRaw.where((t) => t.isIncome == filterState.isIncome).toList();
    }

    // Sort by Date (Newest First) - Sort raw data before mapping
    filteredRaw.sort((a, b) => b.date.compareTo(a.date));

    // --- Store the filtered raw list temporarily ---
    // We'll use this for summary calculation
    final currentFilteredRaw = filteredRaw;

    // --- Map filtered raw data to ViewModels ---
    final List<TransactionViewModel> viewModels = [];
    final dateFormat = DateFormat.Md(); // Or your preferred format
    final accountMap = {for (var acc in state.allAccounts) acc.id: acc};
    final categoryMap = {for (var cat in state.allCategories) cat.id: cat};

    for (final tx in filteredRaw) {
      final category = categoryMap[tx.category.targetId];
      final account = accountMap[tx.fromAccount.targetId];

      final displayAmount =
          '${tx.isIncome ? '+' : ''}${tx.amount.toStringAsFixed(2)} ${account?.currencySymbolOrCurrency ?? ''}';
      final categoryName = category?.title ?? 'Uncategorized';
      final categoryColor = category?.color ?? Colors.grey;
      final categoryIcon = category?.icon ?? Icons.question_mark;
      final accountName = account?.name ?? 'Unknown Account';

      viewModels.add(TransactionViewModel(
        id: tx.id,
        title: tx.title,
        displayAmount: displayAmount,
        categoryName: categoryName,
        categoryColor: categoryColor,
        categoryIcon: categoryIcon,
        displayDate: dateFormat.format(tx.date),
        date: tx.date, // --- ADDED: Pass the original DateTime ---
        isIncome: tx.isIncome,
        accountName: accountName,
      ));
    }
    // --- End Mapping ---

    // Calculate Summary using the filtered RAW data we just prepared
    final summary = await _calculateSummary(currentFilteredRaw,
        filterState.selectedAccount); // Use currentFilteredRaw

    emit(state.copyWith(
      // --- Store the filtered raw list in the final state ---
      filteredTransactions: currentFilteredRaw, // Store the raw list
      // Emit the ViewModels for display
      displayedTransactions: viewModels, // Emit the mapped ViewModels
      summary: summary,
      status: LoadingStatus.success,
    ));
  }
  // --- END REFACTORED _applyFiltersCache ---

  // --- REFACTORED _applySortByDateCache ---
  void _applySortByDateCache() {
    // Re-applying filters automatically handles sorting raw data and re-mapping
    _applyFiltersCache(_filterCubit.state);
  }
  // --- END REFACTORED _applySortByDateCache ---

  void recalculateSummary() async {
    final summary = await _calculateSummary(
        state.filteredTransactions, _filterCubit.state.selectedAccount);
    emit(state.copyWith(summary: summary));
  }

  Future<TransactionSummaryState> _calculateSummary(
      List<Transaction> transactions, Account? selectedAccount) async {
    // Group transactions by currency
    final incomeByCurrency =
        CalculateBalancesUtils.calculateIncomeByCurrency(transactions);
    final expensesByCurrency =
        CalculateBalancesUtils.calculateExpensesByCurrency(transactions);

    // Fetch exchange rates with Defaults.defaultCurrency as the base currency
    final exchangeRates =
        await CurrencyService.fetchExchangeRates(Defaults().defaultCurrency);

    String convertToCurrency =
        selectedAccount?.currency ?? Defaults().defaultCurrency;

    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double totalBalance = 0.0;

    // Convert grouped amounts to Defaults.defaultCurrency
    for (final entry in incomeByCurrency.entries) {
      totalIncome += CurrencyUtils.convertAmount(
        entry.value,
        entry.key,
        convertToCurrency,
        exchangeRates,
      );
    }

    for (final entry in expensesByCurrency.entries) {
      totalExpenses += CurrencyUtils.convertAmount(
        entry.value,
        entry.key,
        convertToCurrency,
        exchangeRates,
      );
    }

    totalBalance = totalIncome - totalExpenses;

    return TransactionSummaryState(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      balance: totalBalance,
    );
  }

  // --- CRUD Operations (Modify state.allTransactions, then re-filter/map) --- //

  Future addTransaction(Transaction transaction) async {
    // Add to repository (ObjectBox assigns ID here if transaction.id is 0)
    final savedId = await _transactionRepository.put(transaction);
    // Fetch the saved transaction to ensure we have the correct ID assigned by ObjectBox
    // and potentially updated fields (like createdAt, updatedAt)
    final savedTransaction = await _transactionRepository.getById(savedId);

    if (savedTransaction != null) {
      final updatedAllTransactions =
          List<Transaction>.from(state.allTransactions)..add(savedTransaction);
      emit(state.copyWith(allTransactions: updatedAllTransactions));
      _applyFiltersCache(
          _filterCubit.state); // Re-apply filters and map to ViewModels
    } else {
      print("Error: Failed to fetch saved transaction after adding.");
      // Optionally revert or show error
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to add transaction"));
      // Re-apply filters even on error to reflect current state
      _applyFiltersCache(_filterCubit.state);
    }
    // Status is set within _applyFiltersCache
  }

  Future addTransactions(List<Transaction> transactions) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    // Add to repository (ObjectBox assigns IDs here)
    final savedIds = await _transactionRepository.putMany(transactions);
    // Fetch the saved transactions to ensure we have correct IDs and timestamps
    // Note: Fetching many by ID might be inefficient, consider alternatives if performance is critical
    final List<Transaction> savedTransactions = [];
    for (final id in savedIds) {
      final tx = await _transactionRepository.getById(id);
      if (tx != null) savedTransactions.add(tx);
    }

    final updatedAllTransactions = List<Transaction>.from(state.allTransactions)
      ..addAll(savedTransactions);
    emit(state.copyWith(allTransactions: updatedAllTransactions));
    _applyFiltersCache(
        _filterCubit.state); // Re-apply filters and map to ViewModels
    // Status is set within _applyFiltersCache
  }

  Future updateTransaction(Transaction transaction) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    // Update in repository (put handles ID check and updates timestamps)
    final savedId = await _transactionRepository.put(transaction);
    // Fetch the updated transaction to ensure we have the latest state
    final updatedTransaction = await _transactionRepository.getById(savedId);

    if (updatedTransaction != null) {
      final index = state.allTransactions
          .indexWhere((t) => t.id == updatedTransaction.id);
      if (index != -1) {
        final updatedAllTransactions =
            List<Transaction>.from(state.allTransactions);
        updatedAllTransactions[index] = updatedTransaction;
        emit(state.copyWith(allTransactions: updatedAllTransactions));
      } else {
        // If not found (e.g., was filtered out), add it back? Or log warning.
        print(
            "Warning: Updated transaction ID ${updatedTransaction.id} not found in current allTransactions list.");
        // Optionally add it back if it should be there:
        // final updatedAllTransactions = List<Transaction>.from(state.allTransactions)..add(updatedTransaction);
        // emit(state.copyWith(allTransactions: updatedAllTransactions));
      }
    } else {
      print("Error: Failed to fetch updated transaction after saving.");
      // Optionally revert or show error
    }
    _applyFiltersCache(
        _filterCubit.state); // Re-apply filters and map to ViewModels
    // Status is set within _applyFiltersCache
  }

  Future deleteTransaction(int transactionId) async {
    // Use soft delete from repository
    final success = await _transactionRepository.remove(transactionId);
    if (success) {
      final updatedAllTransactions =
          List<Transaction>.from(state.allTransactions)
            ..removeWhere((t) => t.id == transactionId);
      emit(state.copyWith(allTransactions: updatedAllTransactions));
    } else {
      print("Failed to soft delete transaction $transactionId");
      // Optionally emit failure state
    }
    _applyFiltersCache(
        _filterCubit.state); // Re-apply filters and map to ViewModels
    // Status is set within _applyFiltersCache (will be success unless error emitted above)
  }

  Future deleteAllTransactions() async {
    emit(state.copyWith(status: LoadingStatus.loading));
    // Use soft delete for current user
    await _transactionRepository.removeAllForCurrentUser();
    emit(state.copyWith(allTransactions: [])); // Clear raw transactions
    _applyFiltersCache(_filterCubit
        .state); // Re-apply filters (will result in empty ViewModels)
    // Status is set within _applyFiltersCache
  }

  // --- Transaction Form Result Handling (Remains the same) --- //
  void handleTransactionFormResult(TransactionResult result) async {
    switch (result.actionType) {
      case ActionType.addNew:
        await addTransaction(result.transaction);
        break;
      case ActionType.edit:
        await updateTransaction(result.transaction);
        break;
      case ActionType.delete:
        await deleteTransaction(result.transaction.id);
        break;
    }
  }

  // --- NEW: Method to get raw transaction for editing ---
  Future<Transaction?> getTransactionForEditing(int id) async {
    try {
      // Fetch the full, raw entity from the repository
      // getById already handles user context and non-deleted status
      final transaction = await _transactionRepository.getById(id);
      if (transaction == null) {
        print(
            "Error: Transaction $id not found or not accessible for editing.");
        emit(state.copyWith(
            status: LoadingStatus.failure,
            errorMessage: "Failed to load transaction details"));
      }
      // You might want to fetch related objects eagerly here if the form needs them immediately
      // e.g., await transaction?.category.load(); await transaction?.fromAccount.load();
      // However, the form should ideally accept IDs and load objects itself if needed.
      return transaction;
    } catch (e) {
      print("Error fetching transaction $id for editing: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to load transaction details"));
      return null;
    }
  }
  // --- End NEW Method ---

  bool hasTransactionsForCategory(int categoryId) {
    return state.allTransactions
        .any((transaction) => transaction.category.targetId == categoryId);
  }

  bool hasTransactionsForAccount(int accountId) {
    return state.allTransactions
        .any((transaction) => transaction.fromAccount.targetId == accountId);
  }

  @override
  Future<void> close() {
    _filterSubscription.cancel(); // Cancel the listener
    return super.close();
  }
}
