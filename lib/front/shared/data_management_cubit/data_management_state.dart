part of 'data_management_cubit.dart';

class DataManagementState extends Equatable {
  final List<Transaction> allTransactions;
  final List<Account> allAccounts;
  final List<Category> allCategories;
  // --- Add field for filtered raw transactions ---
  final List<Transaction> filteredTransactions; // Holds the raw filtered list
  // --- Use ViewModel for display ---
  final List<TransactionViewModel> displayedTransactions;
  // --- End Use ViewModel ---
  final TransactionSummaryState summary;
  final LoadingStatus status;
  final String? errorMessage;

  const DataManagementState({
    this.allTransactions = const [],
    this.allAccounts = const [],
    this.allCategories = const [],
    // --- Initialize new field ---
    this.filteredTransactions = const [], // Initialize as empty
    // --- Use ViewModel for display ---
    this.displayedTransactions = const [],
    // --- End Use ViewModel ---
    this.summary = const TransactionSummaryState(),
    this.status = LoadingStatus.initial,
    this.errorMessage,
  });

  DataManagementState copyWith({
    List<Transaction>? allTransactions,
    List<Account>? allAccounts,
    List<Category>? allCategories,
    // --- Add copyWith parameter ---
    List<Transaction>? filteredTransactions,
    // --- Use ViewModel for display ---
    List<TransactionViewModel>? displayedTransactions,
    // --- End Use ViewModel ---
    TransactionSummaryState? summary,
    LoadingStatus? status,
    String? errorMessage,
    bool? clearError, // Helper to clear error message
  }) {
    return DataManagementState(
      allTransactions: allTransactions ?? this.allTransactions,
      allAccounts: allAccounts ?? this.allAccounts,
      allCategories: allCategories ?? this.allCategories,
      // --- Use new parameter ---
      filteredTransactions: filteredTransactions ?? this.filteredTransactions,
      // --- Use ViewModel for display ---
      displayedTransactions:
          displayedTransactions ?? this.displayedTransactions,
      // --- End Use ViewModel ---
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
        // --- Add to props ---
        filteredTransactions,
        // --- Use ViewModel for display ---
        displayedTransactions,
        // --- End Use ViewModel ---
        summary,
        status,
        errorMessage,
      ];
}
