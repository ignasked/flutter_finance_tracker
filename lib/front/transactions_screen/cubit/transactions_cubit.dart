import 'dart:async';
import 'package:equatable/equatable.dart';

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
import 'package:money_owl/main.dart'; // Import FilterState

part 'transactions_state.dart'; // Updated part directive

class TransactionsCubit extends Cubit<TransactionsState> {
  // Renamed class
  final TransactionRepository _transactionRepository;
  final AccountRepository _accountRepository;
  final CategoryRepository _categoryRepository;
  final FilterCubit _filterCubit; // Inject FilterCubit
  late StreamSubscription<FilterState>
      _filterSubscription; // Listener for filter changes

  TransactionsCubit(
    // Renamed constructor
    this._transactionRepository,
    this._accountRepository,
    this._categoryRepository,
    this._filterCubit, // Accept FilterCubit
  ) : super(const TransactionsState()) {
    _loadInitialData();

    // Listen to filter changes
    _filterSubscription = _filterCubit.stream.listen((filterState) {
      _applyFiltersCache(filterState); // Apply filters when FilterCubit updates
    });
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

  // Future _applyFiltersQuery(FilterState filterState) async {
  //   emit(state.copyWith(status: LoadingStatus.loading));

  //   List<Transaction> filteredTx =
  //       await _transactionRepository.getFiltered(filterState);

  //   emit(state.copyWith(
  //     displayedTransactions: filteredTx,
  //     summary: calculateSummary(filteredTx),
  //     status: LoadingStatus.success, // Ensure status is success after filtering
  //   ));
  // }

  void _applyFiltersCache(FilterState filterState) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    List<Transaction> filtered = List.from(state.allTransactions);

    // Apply Account Filter
    if (filterState.selectedAccount != null) {
      filtered = filtered
          .where((t) =>
              t.fromAccount.target?.id == filterState.selectedAccount!.id)
          .toList();
    }

    // Apply Category Filter
    if (filterState.selectedCategories.isNotEmpty) {
      final categoryIds =
          filterState.selectedCategories.map((c) => c.id).toSet();
      filtered = filtered
          .where((t) => categoryIds.contains(t.category.target?.id))
          .toList();
    }

    // Apply Date Filter
    if (filterState.startDate != null) {
      if (filterState.singleDay) {
        // Filter for a single day (ignore time part)
        final startOfDay = DateTime(filterState.startDate!.year,
            filterState.startDate!.month, filterState.startDate!.day);
        final endOfDay = startOfDay.add(const Duration(days: 1));
        filtered = filtered
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

        filtered = filtered.where((t) {
          final transactionDate = t.date;
          bool afterStart = transactionDate.isAtSameMomentAs(rangeStart) ||
              transactionDate.isAfter(rangeStart);
          bool beforeEnd =
              rangeEnd == null || transactionDate.isBefore(rangeEnd);
          return afterStart && beforeEnd;
        }).toList();
      }
    }

    // Apply Amount Filter (Optional)
    if (filterState.minAmount != null) {
      filtered = filtered
          .where((t) => t.amount.abs() >= filterState.minAmount!)
          .toList();
    }

    // Apply Income/Expense Filter (Optional)
    if (filterState.isIncome != null) {
      filtered =
          filtered.where((t) => t.isIncome == filterState.isIncome).toList();
    }

    // Sort by Date (Newest First)
    filtered.sort((a, b) => b.date.compareTo(a.date));

    // Calculate Summary
    final summary =
        await _calculateSummary(filtered, filterState.selectedAccount);

    emit(state.copyWith(
      displayedTransactions: filtered,
      summary: summary,
      status: LoadingStatus.success, // Ensure status is success after filtering
    ));
  }

  void _applySortByDateCache() {
    emit(state.copyWith(status: LoadingStatus.loading));
    List<Transaction> sorted = List.from(state.displayedTransactions);
    sorted.sort((a, b) => b.date.compareTo(a.date)); // Sort by date descending
    emit(state.copyWith(
        displayedTransactions: sorted, status: LoadingStatus.success));
  }

  void recalculateSummary() async {
    final summary = await _calculateSummary(
        state.displayedTransactions, _filterCubit.state.selectedAccount);
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

// --- CRUD Operations --- //

  // Add a new transaction
  Future addTransaction(Transaction transaction) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    txRepository.put(transaction); // Add to repository
    final updatedAllTransactions = List<Transaction>.from(state.allTransactions)
      ..add(transaction);
    emit(state.copyWith(allTransactions: updatedAllTransactions));
    _applyFiltersCache(_filterCubit.state); // Re-apply filters
    _applySortByDateCache(); // Re-apply sorting
    emit(state.copyWith(status: LoadingStatus.success));
  }

  Future addTransactions(List<Transaction> transactions) async {
    emit(state.copyWith(status: LoadingStatus.loading));
    txRepository.putMany(transactions); // Add to repository
    final updatedAllTransactions = List<Transaction>.from(state.allTransactions)
      ..addAll(transactions);
    emit(state.copyWith(allTransactions: updatedAllTransactions));
    _applyFiltersCache(_filterCubit.state); // Re-apply filters
    _applySortByDateCache(); // Re-apply sorting
    emit(state.copyWith(status: LoadingStatus.success));
  }

  // Update an existing transaction
  Future updateTransaction(Transaction transaction) async {
    emit(state.copyWith(status: LoadingStatus.loading));

    _transactionRepository.put(transaction); // Update in repository
    final index =
        state.allTransactions.indexWhere((t) => t.id == transaction.id);
    if (index != -1 && index < state.allTransactions.length) {
      final updatedAllTransactions =
          List<Transaction>.from(state.allTransactions);
      updatedAllTransactions[index] = transaction;
      emit(state.copyWith(allTransactions: updatedAllTransactions));
    }
    _applyFiltersCache(_filterCubit.state); // Re-apply filters
    _applySortByDateCache(); // Re-apply sorting

    emit(state.copyWith(status: LoadingStatus.success));
  }

  // Delete a transaction
  Future deleteTransaction(int transactionId) async {
    emit(state.copyWith(status: LoadingStatus.loading));

    txRepository.remove(transactionId); // Remove from repository
    final updatedAllTransactions = List<Transaction>.from(state.allTransactions)
      ..removeWhere((t) => t.id == transactionId);
    emit(state.copyWith(allTransactions: updatedAllTransactions));
    _applyFiltersCache(_filterCubit.state); // Re-apply filters

    emit(state.copyWith(status: LoadingStatus.success));
  }

  Future deleteAllTransactions() async {
    emit(state.copyWith(status: LoadingStatus.loading));

    // Make async
    txRepository.removeAll(); // Remove from repository
    emit(state.copyWith(allTransactions: []));
    _applyFiltersCache(_filterCubit.state);

    emit(state.copyWith(status: LoadingStatus.success));
  }

// --- Transaction Form Result Handling --- //

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

  @override
  Future<void> close() {
    _filterSubscription.cancel(); // Cancel the listener
    return super.close();
  }
}
