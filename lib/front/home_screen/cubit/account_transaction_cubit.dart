import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/repositories/transaction_utils.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';

part 'account_transaction_state.dart';

class AccountTransactionCubit extends Cubit<AccountTransactionState> {
  final TransactionRepository txRepo;
  final AccountRepository accRepo;

  // Private field for all transactions
  List<Transaction> _allTransactions = [];

  AccountTransactionCubit(this.txRepo, this.accRepo)
      : super(const AccountTransactionState(
          selectedAccount: null, // Default to "All Accounts"
          displayedTransactions: [],
          allAccounts: [],
          totalIncome: 0.0,
          totalExpenses: 0.0,
          balance: 0.0,
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

  /// Select all accounts and load all transactions
  void _displayTransactionsForAllAccounts() {
    // _allTransactions = txRepo.getAll();
    emit(state.copyWith(
      displayedTransactions: _allTransactions,
    ));
    _calculateSummary(_allTransactions);
  }

  /// Load transactions for a specific account
  void _displayTransactionsForAccount(Account account) {
    final transactions = _allTransactions
        .where((transaction) => transaction.account.targetId == account.id)
        .toList();

    emit(state.copyWith(displayedTransactions: transactions));
    _calculateSummary(transactions);
  }

  /// Display transactions for the selected account or all accounts if none is selected
  void displayTransactionsForSelectedAccount() {
    if (state.selectedAccount == null) {
      _displayTransactionsForAllAccounts(); // Load all accounts
    } else {
      _displayTransactionsForAccount(
          state.selectedAccount!); // Load specific account
    }
  }

  /// Update the selected account
  void updateSelectedAccount(Account? account) {
    if (account == null) {
      emit(state.copyWith(resetSelectedAccount: true));
    } else {
      emit(state.copyWith(selectedAccount: account));
    }
    displayTransactionsForSelectedAccount();
  }

  /// Add a new transaction
  void addTransaction(Transaction transaction) {
    _allTransactions.add(transaction); // Add to the local list

    List<Transaction> transactionsList = List.from(state.displayedTransactions);
    transactionsList.add(transaction);

    txRepo.put(transaction); // Save to the repository
    emit(state.copyWith(displayedTransactions: transactionsList));
    _calculateSummary(transactionsList);
  }

  void addTransactions(List<Transaction> transactions) {
    _allTransactions.addAll(transactions); // Add to the local list

    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.displayedTransactions);
    transactionsList.addAll(transactions);

    txRepo.putMany(transactions); // Save to the repository

    emit(state.copyWith(displayedTransactions: transactionsList));
    _calculateSummary(transactionsList);
  }

  /// Update an existing transaction by ID
  void updateTransaction(Transaction transaction) {
    _allTransactions = _allTransactions.map((t) {
      return t.id == transaction.id ? transaction : t;
    }).toList();

    final updatedTransactions = state.displayedTransactions.map((t) {
      return t.id == transaction.id ? transaction : t;
    }).toList();

    txRepo.put(transaction); // Update in the repository
    emit(state.copyWith(displayedTransactions: updatedTransactions));
    _calculateSummary(updatedTransactions);
  }

  /// Delete a transaction by ID
  void deleteTransaction(Transaction transaction) {
    _allTransactions =
        _allTransactions.where((t) => t.id != transaction.id).toList();

    final updatedTransactions = state.displayedTransactions
        .where((t) => t.id != transaction.id)
        .toList();

    txRepo.remove(transaction.id); // Remove from the repository

    emit(state.copyWith(displayedTransactions: updatedTransactions));
    _calculateSummary(updatedTransactions);
  }

  /// Delete all transactions
  void deleteAllTransactions() {
    _allTransactions.clear(); // Clear the local list

    txRepo.removeAll(); // Remove all from the repository

    emit(state.copyWith(
        displayedTransactions: [],
        totalIncome: 0.0,
        totalExpenses: 0.0,
        balance: 0.0));
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
  void filterTransactions({
    bool? isIncome,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    List<int>? categoryIds,
  }) {
    TransactionFilter filter = BaseTransactionFilter();

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

    /// Reset filters and show all transactions
    void resetFilters() {
      emit(state.copyWith(displayedTransactions: _allTransactions));
      _calculateSummary(_allTransactions);
    }

    final filteredTransactions = filter.filter(state.displayedTransactions);
    emit(state.copyWith(displayedTransactions: filteredTransactions));
    _calculateSummary(filteredTransactions);
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
      totalIncome: totalIncome,
      totalExpenses: totalExpenses,
      balance: balance,
    ));
  }
}
