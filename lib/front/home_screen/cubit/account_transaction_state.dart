part of 'account_transaction_cubit.dart';

class AccountTransactionState extends Equatable {
  final List<Transaction> displayedTransactions; // Filtered transactions
  final Account? selectedAccount;
  final List<Category> selectedCategories;

  final List<Account> allAccounts;

  final double totalIncome;
  final double totalExpenses;
  final double balance;

  const AccountTransactionState({
    this.displayedTransactions = const [],
    this.allAccounts = const [],
    this.selectedCategories = const [],
    this.selectedAccount,
    this.totalIncome = 0.0,
    this.totalExpenses = 0.0,
    this.balance = 0.0,
  });

  /// Creates a copy of this state with the specified properties updated.
  ///
  /// Returns a new [AccountTransactionState] instance with the same values as this state,
  /// except for the properties that are explicitly specified in the method arguments.
  AccountTransactionState copyWith({
    List<Transaction>? displayedTransactions,
    List<Account>? allAccounts,
    List<Category>? selectedCategories,
    Account? selectedAccount,
    bool resetSelectedAccount = false, // Reset selected account to null
    double? totalIncome,
    double? totalExpenses,
    double? balance,
  }) {
    return AccountTransactionState(
      displayedTransactions:
          displayedTransactions ?? this.displayedTransactions,
      allAccounts: allAccounts ?? this.allAccounts,
      selectedAccount:
          resetSelectedAccount ? null : selectedAccount ?? this.selectedAccount,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      totalIncome: totalIncome ?? this.totalIncome,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      balance: balance ?? this.balance,
    );
  }

  @override
  List<Object?> get props => [
        displayedTransactions,
        allAccounts,
        selectedAccount,
        selectedCategories,
        totalIncome,
        totalExpenses,
        balance,
      ];
}
