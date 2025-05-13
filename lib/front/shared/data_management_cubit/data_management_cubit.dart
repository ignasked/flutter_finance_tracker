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
    // Initial load is NOT a refresh
    _loadInitialData(isRefresh: false); // Pass false explicitly

    // Listen to filter changes
    _filterSubscription = _filterCubit.stream.listen((filterState) {
      // Call the corrected _applyFiltersCache
      emit(state.copyWith(status: LoadingStatus.loading));
      _applyFilters(filterState);
      //emit(state.copyWith(status: LoadingStatus.success));
    });
  }

  Future<void> refreshData() async {
    // This is a refresh, so pass true
    await _loadInitialData(isRefresh: true);
  }

  Future<void> _loadInitialData({bool isRefresh = false}) async {
    // Only emit loading if it's NOT a refresh triggered after sync/action
    if (!isRefresh) {
      emit(state.copyWith(status: LoadingStatus.loading));
    }
    try {
      // Fetch all base data
      final allTransactions = await _transactionRepository.getAll();
      final allAccounts = await _accountRepository.getAll();
      final allCategories = await _categoryRepository.getAll();

      // --- Apply filters, map, and summarize directly ---
      final filterState = _filterCubit.state;
      final List<Transaction> filteredRaw =
          await _transactionRepository.getFiltered(filterState);

      // Map filtered raw data to ViewModels
      final List<TransactionViewModel> viewModels = [];
      final dateFormat = DateFormat.Md();
      final accountMap = {for (var acc in allAccounts) acc.id: acc};
      final categoryMap = {for (var cat in allCategories) cat.id: cat};

      for (final tx in filteredRaw) {
        final category = categoryMap[tx.category.targetId];
        final account = accountMap[tx.fromAccount.targetId];
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

      // Calculate Summary using the filtered RAW data
      // Pass allTransactions needed for calculating starting balance
      final summary = await _calculateSummary(
          filteredRaw, filterState.selectedAccount, allTransactions);

      // Emit final success state with all data
      emit(state.copyWith(
        allTransactions: allTransactions,
        allAccounts: allAccounts,
        allCategories: allCategories,
        filteredTransactions: filteredRaw,
        displayedTransactions: viewModels,
        summary: summary,
        status: LoadingStatus.success, // Emit success HERE
        clearError: true, // Clear any previous error
      ));
      // --- End direct application ---
    } catch (e, stacktrace) {
      // Added stacktrace
      print("Error loading initial data (isRefresh: $isRefresh): $e");
      print(stacktrace); // Print stacktrace for better debugging
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Error loading data: $e"));
    }
  }

  List<Category> getEnabledCategoriesCache() {
    List<Category> enabledCategories =
        state.allCategories.where((category) => category.isEnabled).toList();
    return enabledCategories;
  }

  List<Account> getEnabledAccountsCache() {
    List<Account> enabledAccounts =
        state.allAccounts.where((acc) => acc.isEnabled).toList();
    return enabledAccounts;
  }

  void _applyFilters(FilterState filterState) async {
    try {
      // Apply the new filterState using the repository
      final List<Transaction> filteredRaw =
          await _transactionRepository.getFiltered(filterState);

      // Map filtered raw data to ViewModels using existing accounts/categories from state
      final List<TransactionViewModel> viewModels = [];
      final dateFormat = DateFormat.Md();
      // Use accounts/categories already in the state
      final accountMap = {for (var acc in state.allAccounts) acc.id: acc};
      final categoryMap = {for (var cat in state.allCategories) cat.id: cat};

      for (final tx in filteredRaw) {
        final category = categoryMap[tx.category.targetId];
        final account = accountMap[tx.fromAccount.targetId];
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

      // Calculate Summary using the newly filtered RAW data and existing allTransactions
      // Pass state.allTransactions for starting balance calculation
      final summary = await _calculateSummary(
          filteredRaw, filterState.selectedAccount, state.allTransactions);

      // Emit success state with updated filtered/displayed lists and summary
      // Keep existing allTransactions, allAccounts, allCategories
      emit(state.copyWith(
        filteredTransactions: filteredRaw,
        displayedTransactions: viewModels,
        summary: summary,
        status: LoadingStatus.success, // Go directly to success
        clearError: true,
      ));
    } catch (e, stacktrace) {
      print("Error applying filters or mapping ViewModels: $e");
      print(stacktrace);
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Error updating transaction list: $e"));
    }
  }

  void recalculateSummary() async {
    final summary = await _calculateSummary(state.filteredTransactions,
        _filterCubit.state.selectedAccount, state.allTransactions);
    emit(state.copyWith(summary: summary));
  }

  Future<TransactionSummaryState> _calculateSummary(
      List<Transaction> transactionsInPeriod,
      Account? selectedAccount,
      List<Transaction> allTransactionsForStartingBalance) async {
    final defaultCurrency = Defaults().defaultCurrency;
    final exchangeRates =
        await CurrencyService.fetchExchangeRates(defaultCurrency);
    String convertToCurrency = selectedAccount?.currency ?? defaultCurrency;

    final incomeInPeriodByCurrency =
        CalculateBalancesUtils.calculateIncomeByCurrency(transactionsInPeriod);
    final expensesInPeriodByCurrency =
        CalculateBalancesUtils.calculateExpensesByCurrency(
            transactionsInPeriod);

    double periodIncomeConverted = 0.0;
    double periodExpensesConverted = 0.0;
    double startingBalanceConverted = 0.0;
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

    DateTime? periodStartDate = _filterCubit.state.startDate;
    if (_filterCubit.state.singleDay && periodStartDate != null) {
      periodStartDate = DateTime(
          periodStartDate.year, periodStartDate.month, periodStartDate.day);
    }

    if (periodStartDate != null) {
      final transactionsBeforePeriod =
          allTransactionsForStartingBalance.where((t) {
        bool accountMatch = selectedAccount == null ||
            t.fromAccount.targetId == selectedAccount.id ||
            t.toAccount.targetId == selectedAccount.id;
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
    } else {
      final balanceFromAllByCurrency =
          CalculateBalancesUtils.calculateNetBalanceByCurrency(
              allTransactionsForStartingBalance);
      for (final entry in balanceFromAllByCurrency.entries) {
        startingBalanceConverted += CurrencyUtils.convertAmount(
          entry.value,
          entry.key,
          convertToCurrency,
          exchangeRates,
        );
      }
      periodNetChangeConverted = 0;
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
    try {
      final savedId = await _transactionRepository.put(transaction);
      final savedTransaction = await _transactionRepository.getById(savedId);

      if (savedTransaction != null) {
        // Reload all data to ensure allTransactions is up to date
        final allTransactions = await _transactionRepository.getAll();
        // final allAccounts = await _accountRepository.getAll();
        // final allCategories = await _categoryRepository.getAll();
        // Apply filters and update state
        final filterState = _filterCubit.state;
        emit(state.copyWith(
          allTransactions: allTransactions,
          // allAccounts: allAccounts,
          // allCategories: allCategories,
        ));
        _applyFilters(filterState);
      } else {
        print("Error: Failed to fetch saved transaction after adding.");
        emit(state.copyWith(
            status: LoadingStatus.failure,
            errorMessage: "Failed to add transaction"));
      }
    } catch (e, stacktrace) {
      print("Error adding transaction to repository: $e");
      print(stacktrace);
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to save transaction: $e"));
    }
  }

  Future addTransactions(List<Transaction> transactions) async {
    try {
      await _transactionRepository.putMany(transactions);
      // Reload all data to ensure allTransactions is up to date
      final allTransactions = await _transactionRepository.getAll();
      // final allAccounts = await _accountRepository.getAll();
      // final allCategories = await _categoryRepository.getAll();
      // Apply filters and update state
      final filterState = _filterCubit.state;
      emit(state.copyWith(
        allTransactions: allTransactions,
        // allAccounts: allAccounts,
        // allCategories: allCategories,
      ));
      _applyFilters(filterState);
    } catch (e, stacktrace) {
      print("Error adding multiple transactions to repository: $e");
      print(stacktrace);
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to save transactions: $e"));
    }
  }

  Future updateTransaction(Transaction transaction) async {
    try {
      await _transactionRepository.put(transaction);
      _applyFilters(_filterCubit.state);
    } catch (e, stacktrace) {
      print("Error updating transaction in repository: $e");
      print(stacktrace);
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to update transaction: $e"));
    }
  }

  Future<void> deleteTransaction(int transactionId) async {
    // 1. Find the items to remove from the current state synchronously
    final List<TransactionViewModel> updatedDisplayed =
        List.from(state.displayedTransactions)
          ..removeWhere((vm) => vm.id == transactionId);
    final List<Transaction> updatedFiltered =
        List.from(state.filteredTransactions)
          ..removeWhere((tx) => tx.id == transactionId);
    final List<Transaction> updatedAll = List.from(state.allTransactions)
      ..removeWhere((tx) => tx.id == transactionId);

    // Check if the item was actually found and removed from displayed list
    bool itemRemoved =
        updatedDisplayed.length < state.displayedTransactions.length;

    if (!itemRemoved) {
      print(
          "Warning: Transaction ID $transactionId not found in displayed list for immediate removal.");
      // Optionally still proceed with repo delete, or emit failure?
      // Let's proceed with repo delete attempt anyway.
    }

    // 2. Emit the updated state IMMEDIATELY (synchronously)
    // Recalculate summary based on the synchronously updated filtered list
    final summary = await _calculateSummary(
        updatedFiltered, _filterCubit.state.selectedAccount, updatedAll);

    emit(state.copyWith(
      displayedTransactions: updatedDisplayed,
      filteredTransactions: updatedFiltered,
      allTransactions: updatedAll, // Also remove from allTransactions list
      summary: summary,
      status: LoadingStatus.success, // Maintain success status
    ));

    // 3. Perform the repository deletion in the background (fire-and-forget)
    // No need to await this for the UI update
    _transactionRepository.remove(transactionId).then((success) {
      if (!success) {
        print(
            "Error deleting transaction $transactionId from repository (returned false). State might be inconsistent.");
        // Optionally: Emit a specific error state or re-fetch data to correct inconsistency
        // For now, just log the error. A subsequent refreshData would fix it.
        // emit(state.copyWith(status: LoadingStatus.failure, errorMessage: "Failed to delete transaction from storage"));
      } else {
        print(
            "Successfully deleted transaction $transactionId from repository in background.");
        // Optional: If you absolutely need filters reapplied *after* delete confirmation,
        // you could call _applyFiltersCache here, but it might cause a flicker.
        // _applyFiltersCache(_filterCubit.state);
      }
    }).catchError((e, stacktrace) {
      print("Error deleting transaction $transactionId from repository: $e");
      print(stacktrace);
      // Optionally emit error state
      // emit(state.copyWith(status: LoadingStatus.failure, errorMessage: "Failed to delete transaction: $e"));
    });
  }

  Future deleteAllTransactions() async {
    emit(state.copyWith(status: LoadingStatus.loading));
    try {
      final count = await _transactionRepository.removeAllForCurrentUser();
      print("Soft deleted $count transactions locally.");
      emit(state.copyWith(
        allTransactions: [],
        filteredTransactions: [],
        displayedTransactions: [],
        status: LoadingStatus.success,
        summary: const TransactionSummaryState(),
      ));
    } catch (e, stacktrace) {
      print("Error deleting all transactions from repository: $e");
      print(stacktrace);
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to delete all transactions: $e"));
    }
  }

  Future<void> addCategory(Category category) async {
    try {
      final savedId = await _categoryRepository.put(category);
      final savedCategory = await _categoryRepository.getById(savedId);
      if (savedCategory != null) {
        final updatedCategories = List<Category>.from(state.allCategories)
          ..add(savedCategory);
        emit(state.copyWith(
            allCategories: updatedCategories, status: LoadingStatus.success));
      } else {
        throw Exception("Failed to fetch saved category after adding.");
      }
    } catch (e) {
      print("Error adding category: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to add category: ${e.toString()}"));
    }
  }

  Future<void> updateCategory(Category category) async {
    try {
      final savedId = await _categoryRepository.put(category);
      final updatedCategory = await _categoryRepository.getById(savedId);
      if (updatedCategory != null) {
        final index =
            state.allCategories.indexWhere((c) => c.id == updatedCategory.id);
        if (index != -1) {
          final updatedCategories = List<Category>.from(state.allCategories);
          updatedCategories[index] = updatedCategory;

          if (Defaults().defaultCategory.id == updatedCategory.id) {
            Defaults().setDefaultCategoryInstance(updatedCategory);
            Defaults().saveDefaults();
          }

          emit(state.copyWith(
              allCategories: updatedCategories, status: LoadingStatus.success));
          _applyFilters(_filterCubit.state);
        } else {
          print(
              "Warning: Updated category ID ${updatedCategory.id} not found in current allCategories list.");
          emit(state.copyWith(status: LoadingStatus.success));
        }
      } else {
        throw Exception("Failed to fetch updated category after saving.");
      }
    } catch (e) {
      print("Error updating category: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to update category: ${e.toString()}"));
    }
  }

  Future<void> deleteCategory(int categoryId) async {
    if (categoryId >= 1 && categoryId <= 19) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Default categories (ID 1-19) cannot be deleted."));
      return;
    }
    if (hasTransactionsForCategory(categoryId)) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Cannot delete category with existing transactions."));
      return;
    }

    try {
      final success = await _categoryRepository.remove(categoryId);
      if (success) {
        final updatedCategories = List<Category>.from(state.allCategories)
          ..removeWhere((c) => c.id == categoryId);
        emit(state.copyWith(
            allCategories: updatedCategories, status: LoadingStatus.success));
        _applyFilters(_filterCubit.state);
      } else {
        throw Exception("Failed to delete category from repository.");
      }
    } catch (e) {
      print("Error deleting category: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to delete category: ${e.toString()}"));
    }
  }

  Future<void> addAccount(Account account) async {
    try {
      final savedId = await _accountRepository.put(account);
      final savedAccount = await _accountRepository.getById(savedId);
      if (savedAccount != null) {
        final updatedAccounts = List<Account>.from(state.allAccounts)
          ..add(savedAccount);
        emit(state.copyWith(
            allAccounts: updatedAccounts, status: LoadingStatus.success));
        _applyFilters(_filterCubit.state);
      } else {
        throw Exception("Failed to fetch saved account after adding.");
      }
    } catch (e) {
      print("Error adding account: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to add account: ${e.toString()}"));
    }
  }

  Future<void> updateAccount(Account account) async {
    try {
      final savedId = await _accountRepository.put(account);
      final updatedAccount = await _accountRepository.getById(savedId);
      if (updatedAccount != null) {
        final index =
            state.allAccounts.indexWhere((a) => a.id == updatedAccount.id);
        if (index != -1) {
          final updatedAccounts = List<Account>.from(state.allAccounts);
          updatedAccounts[index] = updatedAccount;

          if (Defaults().defaultAccount.id == updatedAccount.id) {
            Defaults().setDefaultAccountInstance(updatedAccount);
          }

          emit(state.copyWith(
              allAccounts: updatedAccounts, status: LoadingStatus.success));
          _filterCubit.resetFilters();
        } else {
          print(
              "Warning: Updated account ID ${updatedAccount.id} not found in current allAccounts list.");
          emit(state.copyWith(status: LoadingStatus.success));
        }
      } else {
        throw Exception("Failed to fetch updated account after saving.");
      }
    } catch (e) {
      print("Error updating account: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to update account: ${e.toString()}"));
    }
  }

  Future<void> deleteAccount(int accountId) async {
    if (accountId == 1 || accountId == 2) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Default accounts cannot be deleted."));
      return;
    }
    if (hasTransactionsForAccount(accountId)) {
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Cannot delete account with existing transactions."));
      return;
    }

    try {
      final success = await _accountRepository.remove(accountId);
      if (success) {
        final updatedAccounts = List<Account>.from(state.allAccounts)
          ..removeWhere((a) => a.id == accountId);
        emit(state.copyWith(
            allAccounts: updatedAccounts, status: LoadingStatus.success));
        _applyFilters(_filterCubit.state);
      } else {
        throw Exception("Failed to delete account from repository.");
      }
    } catch (e) {
      print("Error deleting account: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to delete account: ${e.toString()}"));
    }
  }

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

  Future<Transaction?> getTransactionForEditing(int id) async {
    try {
      final transaction = await _transactionRepository.getById(id);
      if (transaction == null) {
        print(
            "Error: Transaction $id not found or not accessible for editing.");
        emit(state.copyWith(
            status: LoadingStatus.failure,
            errorMessage: "Failed to load transaction details"));
      }
      return transaction;
    } catch (e) {
      print("Error fetching transaction $id for editing: $e");
      emit(state.copyWith(
          status: LoadingStatus.failure,
          errorMessage: "Failed to load transaction details"));
      return null;
    }
  }

  bool hasTransactionsForCategory(int categoryId) {
    return state.allTransactions
        .any((transaction) => transaction.category.targetId == categoryId);
  }

  bool hasTransactionsForAccount(int accountId) {
    return state.allTransactions.any((transaction) =>
        transaction.fromAccount.targetId == accountId ||
        transaction.toAccount.targetId == accountId);
  }

  void updateDefaultCurrency() {
    recalculateSummary();
  }

  @override
  Future<void> close() {
    _filterSubscription.cancel();
    return super.close();
  }
}
