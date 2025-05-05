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
      // Fetch all data again, which includes applying filters
      await _loadInitialData(); // Corrected: Call _loadInitialData which handles filters
    } catch (e) {
      print("Error refreshing transactions: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Error refreshing transactions: $e"));
    }
  }

  Future<void> _loadInitialData() async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      // Fetch all base data
      final allTransactions = await _transactionRepository.getAll();
      final allAccounts = await _accountRepository.getAll();
      final allCategories = await _categoryRepository.getAll();

      // Emit base data first
      emit(state.copyWith(
        allTransactions: allTransactions,
        allAccounts: allAccounts,
        allCategories: allCategories,
        // Keep status loading until filters are applied
      ));

      // Now apply current filters using the freshly loaded data
      _applyFiltersCache(_filterCubit.state);
    } catch (e) {
      print("Error loading initial data: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Error loading initial data: $e"));
    }
  }

  List<Category> getEnabledCategoriesCache() {
    List<Category> enabledCategories =
        state.allCategories.where((category) => category.isEnabled).toList();
    // if (!enabledCategories.contains(Defaults().defaultCategory)) {
    //   enabledCategories.add(Defaults()
    //       .defaultCategory); // Remove default category from enabled list
    // }
    return enabledCategories;
  }

  List<Account> getEnabledAccountsCache() {
    List<Account> enabledAccounts =
        state.allAccounts.where((acc) => acc.isEnabled).toList();
    // if (!enabledAccounts.contains(Defaults().defaultAccount)) {
    //   enabledAccounts.add(Defaults()
    //       .defaultAccount); // Remove default account from enabled list
    // }
    return enabledAccounts;
  }

  // --- REFACTORED _applyFiltersCache ---
  void _applyFiltersCache(FilterState filterState) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      // Add try-catch block for safety during filtering/mapping
      // --- Fetch filtered raw data using the repository method ---
      final List<Transaction> filteredRaw =
          await _transactionRepository.getFiltered(filterState);

      // --- Map filtered raw data to ViewModels ---
      final List<TransactionViewModel> viewModels = [];
      final dateFormat = DateFormat.Md(); // Or your preferred format
      // Fetch accounts/categories needed for mapping efficiently
      // Get all accounts/categories from the state (already loaded)
      final accountMap = {for (var acc in state.allAccounts) acc.id: acc};
      final categoryMap = {for (var cat in state.allCategories) cat.id: cat};

      for (final tx in filteredRaw) {
        // Use the maps for efficient lookup
        final category = categoryMap[tx.category.targetId];
        final account = accountMap[tx.fromAccount.targetId];

        // Handle potential nulls gracefully
        final currencySymbol = account?.currencySymbolOrCurrency ??
            Defaults().defaultCurrencySymbol;
        final displayAmount =
            '${tx.isIncome ? '+' : ''}${tx.amount.toStringAsFixed(2)} $currencySymbol';
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
          date: tx.date,
          isIncome: tx.isIncome,
          accountName: accountName,
        ));
      }
      // --- End Mapping ---

      // Calculate Summary using the filtered RAW data we just fetched
      final summary = await _calculateSummary(
          filteredRaw, filterState.selectedAccount); // Use filteredRaw

      emit(state.copyWith(
        filteredTransactions: filteredRaw, // Store the raw list
        displayedTransactions: viewModels, // Emit the mapped ViewModels
        summary: summary,
        status: LoadingStatus.success,
      ));
    } catch (e, stacktrace) {
      print("Error applying filters or mapping ViewModels: $e");
      print(stacktrace);
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage:
              "Error updating transaction list: $e")); // Corrected: Removed extra characters
    }
  }

  void recalculateSummary() async {
    final summary = await _calculateSummary(
        state.filteredTransactions, _filterCubit.state.selectedAccount);
    emit(state.copyWith(summary: summary));
  }

  Future<TransactionSummaryState> _calculateSummary(
      List<Transaction> transactionsInPeriod, // Renamed for clarity
      Account? selectedAccount) async {
    // Fetch necessary data directly if state might be stale or incomplete
    final defaultCurrency = Defaults().defaultCurrency;
    final exchangeRates =
        await CurrencyService.fetchExchangeRates(defaultCurrency);
    String convertToCurrency = selectedAccount?.currency ?? defaultCurrency;

    // Calculate income/expenses for the given period transactions
    final incomeInPeriodByCurrency =
        CalculateBalancesUtils.calculateIncomeByCurrency(transactionsInPeriod);
    final expensesInPeriodByCurrency =
        CalculateBalancesUtils.calculateExpensesByCurrency(
            transactionsInPeriod);

    double periodIncomeConverted = 0.0;
    double periodExpensesConverted = 0.0;
    double startingBalanceConverted = 0.0; // Balance BEFORE the period starts
    double absoluteEndingBalanceConverted = 0.0;

    // Convert period income/expenses
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

    // Calculate starting balance (balance before the period start date)
    DateTime? periodStartDate = _filterCubit.state.startDate;
    if (_filterCubit.state.singleDay && periodStartDate != null) {
      periodStartDate = DateTime(
          periodStartDate.year, periodStartDate.month, periodStartDate.day);
    }

    if (periodStartDate != null) {
      // Fetch transactions *before* the period start date
      // This requires a separate query or filtering the full list if efficient
      // Option 1: Filter the full list (simpler if allTransactions is reliable)
      final transactionsBeforePeriod = state.allTransactions.where((t) {
        bool accountMatch = selectedAccount == null ||
            t.fromAccount.targetId == selectedAccount.id ||
            t.toAccount.targetId ==
                selectedAccount.id; // Include transfers TO the account
        return accountMatch && t.date.isBefore(periodStartDate!);
      }).toList();

      // Option 2: Perform a dedicated repository query (potentially more efficient for large datasets)
      // final transactionsBeforePeriod = await _transactionRepository.getTransactionsBeforeDate(periodStartDate, selectedAccount);

      final balanceBeforePeriodByCurrency =
          CalculateBalancesUtils.calculateNetBalanceByCurrency(
              transactionsBeforePeriod); // Corrected: Only one argument expected
      for (final entry in balanceBeforePeriodByCurrency.entries) {
        startingBalanceConverted += CurrencyUtils.convertAmount(
          entry.value,
          entry.key,
          convertToCurrency,
          exchangeRates,
        );
      }
    } else {
      // If no start date, starting balance is calculated from all transactions
      // (or could be considered 0 if the filter implies 'all time up to now')
      // Let's calculate from all transactions for consistency if no start date
      final balanceFromAllByCurrency =
          CalculateBalancesUtils.calculateNetBalanceByCurrency(
              state.allTransactions); // Corrected: Only one argument expected
      for (final entry in balanceFromAllByCurrency.entries) {
        startingBalanceConverted += CurrencyUtils.convertAmount(
          entry.value,
          entry.key,
          convertToCurrency,
          exchangeRates,
        );
      }
      // If periodStartDate is null, the 'periodNetChange' effectively becomes the total change
      // So, the absoluteEndingBalance will just be the startingBalance (total balance)
      periodNetChangeConverted =
          0; // Reset period change as it's included in startingBalance
    }

    absoluteEndingBalanceConverted =
        startingBalanceConverted + periodNetChangeConverted;

    return TransactionSummaryState(
      totalIncome: periodIncomeConverted,
      totalExpenses: periodExpensesConverted,
      balance: absoluteEndingBalanceConverted, // This is the ENDING balance
      // Optional: Add starting balance to the state if needed for display
      // startingBalance: startingBalanceConverted,
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
    emit(state.copyWith(status: LoadingStatus.loading)); // Set loading status
    // Use soft delete from repository
    final success = await _transactionRepository.remove(transactionId);
    if (success) {
      // Remove from the local state immediately for responsiveness
      final updatedAllTransactions =
          state.allTransactions.where((tx) => tx.id != transactionId).toList();
      emit(state.copyWith(allTransactions: updatedAllTransactions));
      // Re-apply filters AFTER updating the base list
      _applyFiltersCache(_filterCubit.state);
    } else {
      print("Error deleting transaction $transactionId");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Error deleting transaction $transactionId"));
    }
    // Status is set within _applyFiltersCache or the error case above
  }

  Future deleteAllTransactions() async {
    emit(state.copyWith(status: LoadingStatus.loading));
    // Use soft delete for current user
    final count = await _transactionRepository.removeAllForCurrentUser();
    print("Soft deleted $count transactions locally.");
    // Clear raw transactions and displayed transactions
    emit(state.copyWith(
      allTransactions: [],
      filteredTransactions: [],
      displayedTransactions: [],
      status: LoadingStatus.success, // Set success after clearing
      summary: TransactionSummaryState(), // Reset summary
    ));
    // No need to call _applyFiltersCache as everything is empty
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
            Defaults().setDefaultCategoryInstance(updatedCategory);
            Defaults().saveDefaults();
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
            Defaults().setDefaultAccountInstance(updatedAccount);
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
    // Check both fromAccount and toAccount for transfers
    return state.allTransactions.any((transaction) =>
        transaction.fromAccount.targetId == accountId ||
        transaction.toAccount.targetId == accountId);
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
