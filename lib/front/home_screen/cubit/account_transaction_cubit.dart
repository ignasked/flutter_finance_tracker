import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/repositories/transaction_utils.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_filters_state.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_summary_state.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';

part 'account_transaction_state.dart';

class AccountTransactionCubit extends Cubit<AccountTransactionState> {
  final TransactionRepository txRepo;
  final AccountRepository accRepo;
  // Private field for tracking all transactions
  List<Transaction> _allTransactions = [];

  AccountTransactionCubit(this.txRepo, this.accRepo)
      : super(const AccountTransactionState(
          displayedTransactions: [],
          allAccounts: [],
          filters: TransactionFiltersState(),
          txSummary: TransactionSummaryState(),
        )) {
    _loadAccounts();
    _loadAllTransactions();
  }

  /// Load all transactions from the repository
  void _loadAllTransactions() {
    _allTransactions = txRepo.getAll();
    emit(state.copyWith(
      displayedTransactions: _allTransactions,
    ));
    _calculateSummary(_allTransactions);
  }

  /// Load all accounts from the repository
  void _loadAccounts() {
    final accounts = accRepo.getAll();
    emit(state.copyWith(allAccounts: accounts));
  }

  /// Add a new transaction
  void addTransaction(Transaction transaction) {
    _allTransactions.add(transaction); // Add to the local list
    txRepo.put(transaction); // Save to the repository
    _applyFilters();
    _calculateSummary(state.displayedTransactions);
  }

  void addTransactions(List<Transaction> transactions) {
    _allTransactions.addAll(transactions); // Add to the local list
    txRepo.putMany(transactions); // Save to the repository
    _applyFilters();
    _calculateSummary(state.displayedTransactions);
  }

  /// Update an existing transaction by ID
  void updateTransaction(Transaction transaction) {
    _allTransactions = _allTransactions.map((t) {
      return t.id == transaction.id ? transaction : t;
    }).toList();

    txRepo.put(transaction); // Update in the repository
    _applyFilters();
    _calculateSummary(state.displayedTransactions);
  }

  /// Delete a transaction by ID
  void deleteTransaction(Transaction transaction) {
    _allTransactions =
        _allTransactions.where((t) => t.id != transaction.id).toList();
    txRepo.remove(transaction.id); // Remove from the repository
    _applyFilters();
    _calculateSummary(state.displayedTransactions);
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
    _calculateSummary(filteredTransactions);
  }

  /// Reset filters and show all transactions
  void resetFilters() {
    emit(state.copyWith(
        displayedTransactions: _allTransactions,
        filters: const TransactionFiltersState()));
    _calculateSummary(_allTransactions);
  }

  /// Calculate total income, expenses, and balance
  void _calculateSummary(List<Transaction> transactions) {
    double totalIncome = 0.0;
    double totalExpenses = 0.0;

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        totalIncome += transaction.amount;
      } else {
        totalExpenses += transaction.amount;
      }
    }

    final balance = totalIncome - totalExpenses;

    emit(state.copyWith(
        txSummary: state.txSummary.copyWith(
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      balance: balance,
    )));
  }

  void changeSelectedAccount(Account? account) {
    if (account == null) {
      emit(state.copyWith(
        filters: state.filters.copyWith(resetSelectedAccount: true),
      ));
      _applyFilters();
    } else {
      emit(state.copyWith(
        filters: state.filters.copyWith(selectedAccount: account),
      ));
      _applyFilters();
    }
  }

  void changeSelectedCategories(List<Category> categories) {
    emit(state.copyWith(
      filters: state.filters.copyWith(selectedCategories: categories),
    ));
    _applyFilters();
  }

  void changeDateRange(DateTime? startDate, DateTime? endDate) {
    emit(state.copyWith(
      filters: state.filters.copyWith(startDate: startDate, endDate: endDate),
    ));
    _applyFilters();
  }

  void changeMinAmount(double? minAmount) {
    emit(state.copyWith(
      filters: state.filters.copyWith(minAmount: minAmount),
    ));
    _applyFilters();
  }

  void changeIsIncome(bool? isIncome) {
    emit(state.copyWith(
      filters: state.filters.copyWith(isIncome: isIncome),
    ));
    _applyFilters();
  }

  void _applyFilters() {
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
