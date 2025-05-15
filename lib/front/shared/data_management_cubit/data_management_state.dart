part of 'data_management_cubit.dart';

class DataManagementState extends Equatable {
  final List<Transaction> allTransactions;
  final List<Account> allAccounts;
  final List<Category> allCategories;
  final List<Transaction> filteredTransactions; // Holds the raw filtered list
  // --- Use ViewModel for display ---
  final List<TransactionViewModel> displayedTransactions;
  final TransactionSummaryState summary;
  final LoadingStatus status;
  final String? errorMessage;

  const DataManagementState({
    this.allTransactions = const [],
    this.allAccounts = const [],
    this.allCategories = const [],
    this.filteredTransactions = const [], // Initialize as empty
    this.displayedTransactions = const [],
    this.summary = const TransactionSummaryState(),
    this.status = LoadingStatus.initial,
    this.errorMessage,
  });

  DataManagementState copyWith({
    List<Transaction>? allTransactions,
    List<Account>? allAccounts,
    List<Category>? allCategories,
    List<Transaction>? filteredTransactions,
    List<TransactionViewModel>? displayedTransactions,
    TransactionSummaryState? summary,
    LoadingStatus? status,
    String? errorMessage,
    bool? clearError, // Helper to clear error message
  }) {
    return DataManagementState(
      allTransactions: allTransactions ?? this.allTransactions,
      allAccounts: allAccounts ?? this.allAccounts,
      allCategories: allCategories ?? this.allCategories,
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      displayedTransactions:
          displayedTransactions ?? this.displayedTransactions,
      summary: summary ?? this.summary,
      status: status ?? this.status,
      errorMessage:
          clearError == true ? null : (errorMessage ?? this.errorMessage),
    );
  }

  @override
  List<Object?> get props => [
        allTransactions,
        allAccounts,
        allCategories,
        filteredTransactions,
        displayedTransactions,
        summary,
        status,
        errorMessage,
      ];
}
