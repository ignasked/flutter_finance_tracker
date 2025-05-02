part of 'data_management_cubit.dart';

class DataManagementState extends Equatable {
  final LoadingStatus status;
  final List<Transaction> allTransactions; // All transactions for the user
  final List<Account> allAccounts;
  final List<Category> allCategories;
  final List<Transaction> displayedTransactions; // Filtered and sorted
  final TransactionSummaryState
      summary; // Calculated based on displayedTransactions
  final String? errorMessage;

  const DataManagementState({
    this.status = LoadingStatus.initial,
    this.allTransactions = const [],
    this.displayedTransactions = const [],
    this.allAccounts = const [],
    this.allCategories = const [],
    this.summary = const TransactionSummaryState(),
    this.errorMessage,
  });

  DataManagementState copyWith({
    LoadingStatus? status,
    List<Transaction>? allTransactions,
    List<Transaction>? displayedTransactions,
    List<Account>? allAccounts,
    List<Category>? allCategories,
    TransactionSummaryState? summary,
    String? errorMessage,
    bool clearErrorMessage = false,
  }) {
    return DataManagementState(
      status: status ?? this.status,
      allTransactions: allTransactions ?? this.allTransactions,
      displayedTransactions:
          displayedTransactions ?? this.displayedTransactions,
      allAccounts: allAccounts ?? this.allAccounts,
      allCategories: allCategories ?? this.allCategories,
      summary: summary ?? this.summary,
      errorMessage:
          clearErrorMessage ? null : errorMessage ?? this.errorMessage,
    );
  }

  @override
  List<Object?> get props => [
        status,
        allTransactions,
        displayedTransactions,
        allAccounts,
        allCategories,
        summary,
        errorMessage,
      ];
}
