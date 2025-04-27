part of 'account_transaction_cubit.dart';

class AccountTransactionState extends Equatable {
  final List<Transaction> displayedTransactions; // Filtered transactions
  final List<Account> allAccounts;
  final TransactionFiltersState filters; // Filters applied to transactions

  final double totalIncome;
  final double totalExpenses;
  final double balance;

  const AccountTransactionState({
    this.displayedTransactions = const [],
    this.allAccounts = const [],
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
    this.balance = 0.0,
    this.filters = const TransactionFiltersState(),
  });

  /// Creates a copy of this state with the specified properties updated.
  ///
  /// Returns a new [AccountTransactionState] instance with the same values as this state,
  /// except for the properties that are explicitly specified in the method arguments.
  AccountTransactionState copyWith({
    List<Transaction>? displayedTransactions,
    List<Account>? allAccounts,
    final TransactionFiltersState? filters, // Grouped filters
    double? totalIncome,
    double? totalExpenses,
    double? balance,
  }) {
    return AccountTransactionState(
      displayedTransactions:
          displayedTransactions ?? this.displayedTransactions,
      allAccounts: allAccounts ?? this.allAccounts,
      filters: filters ?? this.filters,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      balance: balance ?? this.balance,
    );
  }

  @override
  List<Object?> get props => [
        displayedTransactions,
        allAccounts,
        filters,
        totalIncome,
        totalExpenses,
        balance,
      ];
}
