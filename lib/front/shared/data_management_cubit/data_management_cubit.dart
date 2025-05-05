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

  Future<void> refreshTransactions() async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final transactions = await _transactionRepository.getAll();
      emit(state.copyWith(
          allTransactions: transactions,
          status: LoadingStatus.success)); // Set status before applying filters
      _applyFiltersCache(_filterCubit.state); // Re-apply filters
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
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

  void recalculateSummary() async {
    final summary = await _calculateSummary(
        state.filteredTransactions, _filterCubit.state.selectedAccount);
    emit(state.copyWith(summary: summary));
  }

  Future<TransactionSummaryState> _calculateSummary(
      List<Transaction> transactionsInPeriod, // Renamed for clarity
      Account? selectedAccount) async {
    final filterState = _filterCubit.state;
    final allTransactions = state.allTransactions;
    final incomeInPeriodByCurrency =
        CalculateBalancesUtils.calculateIncomeByCurrency(transactionsInPeriod);
    final expensesInPeriodByCurrency =
        CalculateBalancesUtils.calculateExpensesByCurrency(
            transactionsInPeriod);
    final exchangeRates =
        await CurrencyService.fetchExchangeRates(Defaults().defaultCurrency);
    String convertToCurrency =
        selectedAccount?.currency ?? Defaults().defaultCurrency;

    double periodIncomeConverted = 0.0;
    double periodExpensesConverted = 0.0;
    double startingBalanceConverted = 0.0; // Balance BEFORE the period starts
    double absoluteEndingBalanceConverted = 0.0;

    for (final entry in incomeInPeriodByCurrency.entries) {
      periodIncomeConverted += CurrencyUtils.convertAmount(
        entry.value,
        entry.key,
        convertToCurrency,
        exchangeRates,
      );
    }
    for (final entry in expensesInPeriodByCurrency.entries) {
      periodExpensesConverted += CurrencyUtils.convertAmount(
        entry.value,
        entry.key,
        convertToCurrency,
        exchangeRates,
      );
    }

    double periodNetChangeConverted =
        periodIncomeConverted - periodExpensesConverted;

    DateTime? periodStartDate = filterState.startDate;
    if (filterState.singleDay && periodStartDate != null) {
      periodStartDate = DateTime(
          periodStartDate.year, periodStartDate.month, periodStartDate.day);
    }
    if (periodStartDate != null) {
      final transactionsBeforePeriod = allTransactions.where((t) {
        bool accountMatch = selectedAccount == null ||
            t.fromAccount.targetId == selectedAccount.id;
        return accountMatch && t.date.isBefore(periodStartDate!);
      }).toList();
      final balanceBeforePeriodByCurrency =
          CalculateBalancesUtils.calculateNetBalanceByCurrency(
              transactionsBeforePeriod);
      for (final entry in balanceBeforePeriodByCurrency.entries) {
        startingBalanceConverted += CurrencyUtils.convertAmount(
          entry.value,
          entry.key,
          convertToCurrency,
          exchangeRates,
        );
      }
    }

    absoluteEndingBalanceConverted =
        startingBalanceConverted + periodNetChangeConverted;

    return TransactionSummaryState(
      totalIncome: periodIncomeConverted,
      totalExpenses: periodExpensesConverted,
      balance: absoluteEndingBalanceConverted,
    );
  }

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

  // --- Category Management Methods ---

  Future<void> addCategory(Category category) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final savedId = await _categoryRepository.put(category);
      final savedCategory = await _categoryRepository.getById(savedId);
      if (savedCategory != null) {
        final updatedCategories = List<Category>.from(state.allCategories)
          ..add(savedCategory);
        emit(state.copyWith(
            allCategories: updatedCategories, status: LoadingStatus.success));
        // Re-apply filters if category changes affect displayed transactions (e.g., new category used)
        //_applyFiltersCache(_filterCubit.state);
      } else {
        throw Exception("Failed to fetch saved category after adding.");
      }
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> updateCategory(Category category) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final savedId = await _categoryRepository.put(category);
      final updatedCategory = await _categoryRepository.getById(savedId);
      if (updatedCategory != null) {
        final index =
            state.allCategories.indexWhere((c) => c.id == updatedCategory.id);
        if (index != -1) {
          final updatedCategories = List<Category>.from(state.allCategories);
          updatedCategories[index] = updatedCategory;

          // Update default category if necessary
          if (Defaults().defaultCategory.id == updatedCategory.id) {
            Defaults().defaultCategory = updatedCategory;
          }

          emit(state.copyWith(
              allCategories: updatedCategories, status: LoadingStatus.success));
          // Re-apply filters as category details (like name, color) might have changed
          _applyFiltersCache(_filterCubit.state);
        } else {
          // Category wasn't in the list, maybe add it? Or log warning.
          print(
              "Warning: Updated category ID ${updatedCategory.id} not found in current allCategories list.");
          emit(state.copyWith(status: LoadingStatus.success)); // Still success?
        }
      } else {
        throw Exception("Failed to fetch updated category after saving.");
      }
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    // Prevent deletion of default categories
    if (categoryId >= 1 && categoryId <= 19) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Default categories (ID 1-19) cannot be deleted."));
      return;
    }
    // Check if transactions exist for this category
    if (hasTransactionsForCategory(categoryId)) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Cannot delete category with existing transactions."));
      return;
    }

    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final success = await _categoryRepository.remove(categoryId);
      if (success) {
        final updatedCategories = List<Category>.from(state.allCategories)
          ..removeWhere((c) => c.id == categoryId);
        emit(state.copyWith(
            allCategories: updatedCategories, status: LoadingStatus.success));
        // Re-apply filters if needed (though deleting an unused category shouldn't affect filters)
        _applyFiltersCache(_filterCubit.state);
      } else {
        throw Exception("Failed to delete category from repository.");
      }
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  // --- End Category Management Methods ---

  // --- Account Management Methods ---

  Future<void> addAccount(Account account) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final savedId = await _accountRepository.put(account);
      final savedAccount = await _accountRepository.getById(savedId);
      if (savedAccount != null) {
        final updatedAccounts = List<Account>.from(state.allAccounts)
          ..add(savedAccount);
        emit(state.copyWith(
            allAccounts: updatedAccounts, status: LoadingStatus.success));
        // Re-apply filters if account changes affect displayed transactions
        _applyFiltersCache(_filterCubit.state);
      } else {
        throw Exception("Failed to fetch saved account after adding.");
      }
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> updateAccount(Account account) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final savedId = await _accountRepository.put(account);
      final updatedAccount = await _accountRepository.getById(savedId);
      if (updatedAccount != null) {
        final index =
            state.allAccounts.indexWhere((a) => a.id == updatedAccount.id);
        if (index != -1) {
          final updatedAccounts = List<Account>.from(state.allAccounts);
          updatedAccounts[index] = updatedAccount;

          // Update default account if necessary
          if (Defaults().defaultAccount.id == updatedAccount.id) {
            Defaults().defaultAccount = updatedAccount;
          }

          emit(state.copyWith(
              allAccounts: updatedAccounts, status: LoadingStatus.success));
          _filterCubit.resetFilters();
          // Re-apply filters as account details might have changed
          //_applyFiltersCache(_filterCubit.state);
        } else {
          print(
              "Warning: Updated account ID ${updatedAccount.id} not found in current allAccounts list.");
          emit(state.copyWith(status: LoadingStatus.success));
        }
      } else {
        throw Exception("Failed to fetch updated account after saving.");
      }
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  Future<void> deleteAccount(int accountId) async {
    // Prevent deletion of accounts 1 and 2 (default accounts)
    if (accountId == 1 || accountId == 2) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Default accounts cannot be deleted."));
      return;
    }
    // Check if transactions exist for this account
    if (hasTransactionsForAccount(accountId)) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Cannot delete account with existing transactions."));
      return;
    }

    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final success = await _accountRepository.remove(accountId);
      if (success) {
        final updatedAccounts = List<Account>.from(state.allAccounts)
          ..removeWhere((a) => a.id == accountId);
        emit(state.copyWith(
            allAccounts: updatedAccounts, status: LoadingStatus.success));
        // Re-apply filters if needed
        _applyFiltersCache(_filterCubit.state);
      } else {
        throw Exception("Failed to delete account from repository.");
      }
    } catch (e) {
      emit(state.copyWith(
          status: LoadingStatus.failure, errorMessage: e.toString()));
    }
  }

  // --- End Account Management Methods ---

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

  void updateDefaultCurrency() {
    // This should trigger necessary recalculations/refreshes within the Cubit
    recalculateSummary(); // Example: Recalculate summary based on new default
  }

  @override
  Future<void> close() {
    _filterSubscription.cancel(); // Cancel the listener
    return super.close();
  }
}
