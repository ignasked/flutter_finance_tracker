import 'dart:async';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/models/transaction_filter_decorator.dart';
import 'package:money_owl/backend/services/currency_service.dart';
import 'package:money_owl/backend/utils/currency_utils.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/home_screen/cubit/date_cubit.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_filters_state.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_summary_state.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';

part 'account_transaction_state.dart';

class AccountTransactionCubit extends Cubit<AccountTransactionState> {
  late final StreamSubscription<DateState> _dateSubscription;
  final TransactionRepository txRepo;
  final AccountRepository accRepo;
  final CategoryRepository catRepo;
  // Private field for tracking all transactions
  List<Transaction> _allTransactions = [];

  AccountTransactionCubit(
      this.txRepo, this.accRepo, this.catRepo, DateCubit dateCubit)
      : super(const AccountTransactionState(
          displayedTransactions: [],
          allAccounts: [],
          filters: TransactionFiltersState(),
          txSummary: TransactionSummaryState(),
        )) {
    loadAccounts();
    loadAllTransactions();

    _dateSubscription = dateCubit.stream.listen((dateState) {
      if (dateState.selectedEndDate == null) {
        changeSingleDay(dateState.selectedStartDate);
      } else if (dateState.selectedEndDate != null) {
        changeDateRange(dateState.selectedStartDate, dateState.selectedEndDate);
      }
    });
  }

  @override
  Future<void> close() {
    _dateSubscription.cancel();
    return super.close();
  }

  /// Load all transactions from the repository
  void loadAllTransactions() {
    _allTransactions = txRepo.getAll();
    emit(state.copyWith(
      displayedTransactions: _allTransactions,
    ));
    calculateSummary(_allTransactions);
  }

  /// Load all accounts from the repository
  void loadAccounts() {
    final accounts = accRepo.getAll();
    emit(state.copyWith(allAccounts: accounts));
  }

  /// Add a new transaction
  void addTransaction(Transaction transaction) {
    _allTransactions.add(transaction); // Add to the local list
    txRepo.put(transaction); // Save to the repository
    applyFilters();
    calculateSummary(state.displayedTransactions);
  }

  void addTransactions(List<Transaction> transactions) {
    _allTransactions.addAll(transactions); // Add to the local list
    txRepo.putMany(transactions); // Save to the repository
    applyFilters();
    calculateSummary(state.displayedTransactions);
  }

  /// Update an existing transaction by ID
  void updateTransaction(Transaction transaction) {
    _allTransactions = _allTransactions.map((t) {
      return t.id == transaction.id ? transaction : t;
    }).toList();

    txRepo.put(transaction); // Update in the repository
    applyFilters();
    calculateSummary(state.displayedTransactions);
  }

  /// Delete a transaction by ID
  void deleteTransaction(Transaction transaction) {
    _allTransactions =
        _allTransactions.where((t) => t.id != transaction.id).toList();
    txRepo.remove(transaction.id); // Remove from the repository
    applyFilters();
    calculateSummary(state.displayedTransactions);
  }

  /// Delete all transactions
  void deleteAllTransactions() {
    _allTransactions.clear(); // Clear the local list
    txRepo.removeAll(); // Remove all from the repository
    emit(state.copyWith(
        displayedTransactions: [], txSummary: const TransactionSummaryState()));
  }

  // Receive result from transaction form screen and handle it
  void handleTransactionFormResult(TransactionResult transactionFormResult) {
    switch (transactionFormResult.actionType) {
      case ActionType.addNew:
        addTransaction(transactionFormResult.transaction);
        break;
      case ActionType.edit:
        if (transactionFormResult.index == null) return;
        updateTransaction(transactionFormResult.transaction);
        break;
      case ActionType.delete:
        deleteTransaction(transactionFormResult.transaction);
        break;
    }
  }

  // Filter transactions
  void _filterTransactions({
    bool? isIncome,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    List<int>? categoryIds,
    Account? account,
  }) {
    TransactionFilter filter = BaseTransactionFilter();

    if (account != null) {
      filter = AccountFilterDecorator(
        account: account,
        nextFilter: filter,
      );
    }

    if (startDate != null && endDate != null) {
      filter = DateFilterDecorator(
        startDate: startDate,
        endDate: endDate,
        nextFilter: filter,
      );
    }

    if (startDate != null && endDate == null) {
      filter = DateFilterDecorator(
        startDate: startDate,
        endDate: startDate,
        nextFilter: filter,
      );
    }

    if (minAmount != null) {
      filter = AmountFilterDecorator(
        minAmount: minAmount,
        nextFilter: filter,
      );
    }

    if (isIncome != null) {
      filter = TypeFilterDecorator(
        isIncome: isIncome,
        nextFilter: filter,
      );
    }

    if (categoryIds != null && categoryIds.isNotEmpty) {
      filter = CategoryFilterDecorator(
        categoryIds: categoryIds,
        nextFilter: filter,
      );
    }

    final filteredTransactions = filter.filter(_allTransactions);
    emit(state.copyWith(displayedTransactions: filteredTransactions));
    calculateSummary(filteredTransactions);
  }

  /// Reset filters and show all transactions
  void resetFilters() {
    emit(state.copyWith(
        displayedTransactions: _allTransactions,
        filters: const TransactionFiltersState()));
    calculateSummary(_allTransactions);
  }

  /// Calculate total income, expenses, and balance
  void calculateSummary(List<Transaction> transactions) async {
    double totalIncome = 0.0;
    double totalExpenses = 0.0;
    double totalBalance = 0.0;

    final balancesCalculator = _CalculateBalances(transactions);

    // Group transactions by currency
    final incomeByCurrency = balancesCalculator.calculateIncomeByCurrency();
    final expensesByCurrency = balancesCalculator.calculateExpensesByCurrency();

    // Group transactions by account
    final accountBalances = balancesCalculator.calculateAccountBalances();

    // Fetch exchange rates with Defaults.defaultCurrency as the base currency
    final exchangeRates =
        await CurrencyService.fetchExchangeRates(Defaults().defaultCurrency);

    String convertToCurrency =
        state.filters.selectedAccount?.currency ?? Defaults().defaultCurrency;

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

//     // Update account balances in the repository and refresh the accounts list
//     final updatedAccounts = state.allAccounts;
//     for (final entry in accountBalances.entries) {
//       final account = accRepo.getById(entry.key);
//       if (account != null) {
//         final updatedAccount = account.copyWith(balance: entry.value);
//         accRepo.put(updatedAccount);
//         final index = updatedAccounts.indexWhere((a) => a.id == entry.key);
//         if (index != -1) {
//           updatedAccounts[index] =
//               updatedAccount; // Update the account in the list
//         }
//       }
//     }
// //loadAccounts(); // Refresh account list
//     //loadAllTransactions();

//     emit(state.copyWith(
//       allAccounts: updatedAccounts,
//       txSummary: state.txSummary.copyWith(
//         totalIncome: totalIncome,
//         totalExpenses: totalExpenses,
//         balance: totalBalance,
//       ),
//     ));

    emit(state.copyWith(
      txSummary: state.txSummary.copyWith(
        totalIncome: totalIncome,
        totalExpenses: totalExpenses,
        balance: totalBalance,
      ),
    ));
  }

  void changeSelectedAccount(Account? account) {
    if (account == null) {
      emit(state.copyWith(
        filters: state.filters.copyWith(resetSelectedAccount: true),
      ));
      applyFilters();
    } else {
      emit(state.copyWith(
        filters: state.filters.copyWith(selectedAccount: account),
      ));
      applyFilters();
    }
  }

  void changeSelectedCategories(List<Category> categories) {
    emit(state.copyWith(
      filters: state.filters.copyWith(selectedCategories: categories),
    ));
    applyFilters();
  }

  void changeDateRange(DateTime? startDate, DateTime? endDate) {
    emit(state.copyWith(
      filters: state.filters.copyWith(startDate: startDate, endDate: endDate),
    ));
    applyFilters();
  }

  void changeSingleDay(DateTime? singleDay) {
    emit(state.copyWith(
      filters: state.filters.copyWith(startDate: singleDay, singleDay: true),
    ));
    applyFilters();
  }

  void changeMinAmount(double? minAmount) {
    emit(state.copyWith(
      filters: state.filters.copyWith(minAmount: minAmount),
    ));
    applyFilters();
  }

  void changeIsIncome(bool? isIncome) {
    emit(state.copyWith(
      filters: state.filters.copyWith(isIncome: isIncome),
    ));
    applyFilters();
  }

  void applyFilters() {
    final filters = state.filters;
    _filterTransactions(
      isIncome: filters.isIncome,
      startDate: filters.startDate,
      endDate: filters.endDate,
      minAmount: filters.minAmount,
      categoryIds: filters.selectedCategories.map((c) => c.id).toList(),
      account: filters.selectedAccount,
    );
  }
}

class _CalculateBalances {
  final List<Transaction> transactions;

  _CalculateBalances(this.transactions);

  Map<int, double> calculateAccountBalances() {
    final Map<int, double> accountBalances = {};

    for (final transaction in transactions) {
      final accountId = transaction.fromAccount.targetId;
      final amount = transaction.amount;

      if (accountId != null) {
        accountBalances[accountId] = (accountBalances[accountId] ?? 0.0) +
            (transaction.isIncome ? amount : -amount);
      }
    }

    return accountBalances;
  }

  Map<String, double> calculateIncomeByCurrency() {
    final Map<String, double> incomeByCurrency = {};

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        final currency = transaction.fromAccount.target?.currency ??
            Defaults().defaultCurrency;
        incomeByCurrency[currency] =
            (incomeByCurrency[currency] ?? 0.0) + transaction.amount;
      }
    }

    return incomeByCurrency;
  }

  Map<String, double> calculateExpensesByCurrency() {
    final Map<String, double> expensesByCurrency = {};

    for (final transaction in transactions) {
      if (!transaction.isIncome) {
        final currency = transaction.fromAccount.target?.currency ??
            Defaults().defaultCurrency;
        expensesByCurrency[currency] =
            (expensesByCurrency[currency] ?? 0.0) + transaction.amount;
      }
    }

    return expensesByCurrency;
  }
}
