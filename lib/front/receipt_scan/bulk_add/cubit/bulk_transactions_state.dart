part of 'bulk_transactions_cubit.dart';

class BulkTransactionsState extends Equatable {
  final List<Transaction> transactions;
  final List<Transaction> originalTransactions;
  final double totalExpenses;
  final double receiptTotalAmount;
  final String storeName;
  final DateTime selectedDate;
  final Account? selectedAccount;
  final String? warningMessage;
  final bool discountsApplied;

  const BulkTransactionsState({
    required this.transactions,
    required this.originalTransactions,
    required this.selectedDate,
    required this.storeName,
    required this.receiptTotalAmount,
    this.totalExpenses = 0.0,
    this.selectedAccount,
    this.warningMessage,
    this.discountsApplied = false,
  });

  BulkTransactionsState copyWith({
    List<Transaction>? transactions,
    List<Transaction>? originalTransactions,
    double? totalExpenses,
    double? receiptTotalAmount,
    String? storeName,
    DateTime? selectedDate,
    Account? selectedAccount,
    String? warningMessage,
    bool? discountsApplied,
  }) {
    return BulkTransactionsState(
      transactions: transactions ?? this.transactions,
      originalTransactions: originalTransactions ?? this.originalTransactions,
      totalExpenses: totalExpenses ?? this.totalExpenses,
      receiptTotalAmount: receiptTotalAmount ?? this.receiptTotalAmount,
      storeName: storeName ?? this.storeName,
      selectedDate: selectedDate ?? this.selectedDate,
      selectedAccount: selectedAccount ?? this.selectedAccount,
      warningMessage: warningMessage,
      discountsApplied: discountsApplied ?? this.discountsApplied,
    );
  }

  @override
  List<Object?> get props => [
        transactions,
        originalTransactions,
        totalExpenses,
        receiptTotalAmount,
        storeName,
        selectedDate,
        selectedAccount,
        warningMessage,
        discountsApplied,
      ];
}
