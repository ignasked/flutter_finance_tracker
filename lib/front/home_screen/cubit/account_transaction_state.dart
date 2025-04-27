part of 'account_transaction_cubit.dart';

class AccountTransactionState extends Equatable {
  final List<Transaction> displayedTransactions; // Filtered transactions
  final List<Account> allAccounts;
  final TransactionFiltersState filters; // Filters applied to transactions
  final TransactionSummaryState txSummary; // Summary of transactions

  const AccountTransactionState({
    this.displayedTransactions = const [],
    this.allAccounts = const [],
    this.filters = const TransactionFiltersState(),
    this.txSummary = const TransactionSummaryState(),
  });

  /// Creates a copy of this state with the specified properties updated.
  ///
  /// Returns a new [AccountTransactionState] instance with the same values as this state,
  /// except for the properties that are explicitly specified in the method arguments.
  AccountTransactionState copyWith({
    List<Transaction>? displayedTransactions,
    List<Account>? allAccounts,
    final TransactionFiltersState? filters, // Grouped filters
    final TransactionSummaryState? txSummary,
  }) {
    return AccountTransactionState(
      displayedTransactions:
          displayedTransactions ?? this.displayedTransactions,
      allAccounts: allAccounts ?? this.allAccounts,
      filters: filters ?? this.filters,
      txSummary: txSummary ?? this.txSummary,
    );
  }

  @override
  List<Object?> get props => [
        displayedTransactions,
        allAccounts,
        filters,
        txSummary,
      ];
}
