part of 'bulk_transactions_cubit.dart';

class BulkTransactionsState extends Equatable {
  final List<Transaction> transactions; // Raw transaction data
  final List<TransactionViewModel>
      displayedTransactions; // ViewModels for display
  final List<Transaction>
      originalTransactions; // For restoring pre-merge/discount state
  final DateTime selectedDate;
  final Account? selectedAccount;
  final String storeName;
  final double receiptTotalAmount;
  final double calculatedTotalExpenses;
  final bool discountsApplied; // Flag if discounts have been processed
  final LoadingStatus loadingStatus; // Add loading status

  const BulkTransactionsState({
    required this.transactions,
    this.displayedTransactions = const [], // Initialize as empty
    required this.originalTransactions,
    required this.selectedDate,
    this.selectedAccount,
    required this.storeName,
    required this.receiptTotalAmount,
    this.calculatedTotalExpenses = 0.0,
    this.discountsApplied = false,
    this.loadingStatus = LoadingStatus.initial, // Default to initial
  });

  BulkTransactionsState copyWith({
    List<Transaction>? transactions,
    List<TransactionViewModel>? displayedTransactions, // Add copyWith support
    List<Transaction>? originalTransactions,
    DateTime? selectedDate,
    Account? selectedAccount,
    // Use ValueGetter to allow setting account to null explicitly
    ValueGetter<Account?>? selectedAccountGetter,
    String? storeName,
    double? receiptTotalAmount,
    double? calculatedTotalExpenses,
    bool? discountsApplied,
    LoadingStatus? loadingStatus, // Add loading status to copyWith
  }) {
    return BulkTransactionsState(
      transactions: transactions ?? this.transactions,
      displayedTransactions: displayedTransactions ??
          this.displayedTransactions, // Add to copyWith
      originalTransactions: originalTransactions ?? this.originalTransactions,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedAccount: selectedAccountGetter != null
          ? selectedAccountGetter()
          : (selectedAccount ?? this.selectedAccount),
      storeName: storeName ?? this.storeName,
      receiptTotalAmount: receiptTotalAmount ?? this.receiptTotalAmount,
      calculatedTotalExpenses:
          calculatedTotalExpenses ?? this.calculatedTotalExpenses,
      discountsApplied: discountsApplied ?? this.discountsApplied,
      loadingStatus: loadingStatus ?? this.loadingStatus, // Add loading status
    );
  }

  @override
  List<Object?> get props => [
        transactions,
        displayedTransactions, // Add to props
        originalTransactions,
        selectedDate,
        selectedAccount,
        storeName,
        receiptTotalAmount,
        calculatedTotalExpenses,
        discountsApplied,
        loadingStatus, // Add loading status to props
      ];
}
