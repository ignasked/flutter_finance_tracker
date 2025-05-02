import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';

part 'bulk_transactions_state.dart';

class BulkTransactionsCubit extends Cubit<BulkTransactionsState> {
  BulkTransactionsCubit({
    required List<Transaction> transactions,
    required String storeName,
    required DateTime receiptDate,
    required double receiptTotalAmount,
  }) : super(BulkTransactionsState(
          transactions: transactions,
          originalTransactions: List.from(transactions),
          selectedDate: receiptDate,
          storeName: storeName,
          receiptTotalAmount: receiptTotalAmount,
          selectedAccount: Defaults().defaultAccount,
        )) {
    // Apply defaults on initialization
    _applyAccountToAllTransactions();
    _applyDateToAllTransactions();
    _calculateTotalExpenses();
  }

  // Process discounts in the transaction list
  void processDiscounts() {
    if (state.discountsApplied) {
      // If discounts were already applied, restore original transactions first
      restoreOriginalTransactions();
    }

    // Store current state before processing
    List<Transaction> originalTransactions = List.from(state.transactions);

    // First, identify and apply item-specific discounts
    var transactions = _applyItemDiscounts(List.from(state.transactions));

    // Then, distribute any global discounts
    //transactions = _applyGlobalDiscounts(transactions);

    // Emit updated state
    emit(state.copyWith(
      transactions: transactions,
      originalTransactions: originalTransactions,
      discountsApplied: true,
    ));

    // Recalculate total after processing
    _calculateTotalExpenses();
  }

  // Restore transactions to their state before discount processing
  void restoreOriginalTransactions() {
    emit(state.copyWith(
      transactions: List.from(state.originalTransactions),
      discountsApplied: false,
    ));
    _calculateTotalExpenses();
  }

  // Helper method to check if a transaction is a discount
  bool _isDiscountCategory(Category? category, String discountType) {
    if (category == null) return false;

    // Check if the category title matches the discount type
    // and it's an expense type category (discounts reduce expenses)
    return category.title?.toLowerCase() == discountType.toLowerCase() &&
        category.type == TransactionType.income;
  }

  // Process item-specific discounts
  List<Transaction> _applyItemDiscounts(List<Transaction> inputTransactions) {
    // Temporary list to hold transactions after processing
    final List<Transaction> processedTransactions = [];

    // Find discount transactions and apply them to the preceding item
    for (int i = 0; i < inputTransactions.length; i++) {
      final transaction = inputTransactions[i];
      final category = transaction.category.target;

      // Check if this is a discount transaction
      if (_isDiscountCategory(category, 'Discount for item')) {
        // Skip if this is the first transaction (no preceding item to apply discount to)
        if (processedTransactions.isEmpty) {
          // Add as a regular transaction if no preceding item
          processedTransactions.add(transaction);
          continue;
        }

        // Get the preceding transaction to apply discount to
        final previousIndex = processedTransactions.length - 1;
        final previousTransaction = processedTransactions[previousIndex];

        final newAmount = transaction.amount > 0
            ? previousTransaction.amount - transaction.amount
            : previousTransaction.amount + transaction.amount;

        // Create a new transaction with the discount applied
        final updatedTransaction = Transaction(
          id: previousTransaction.id,
          title: previousTransaction.title,
          amount: newAmount,
          date: previousTransaction.date,
          description: previousTransaction.description != null
              ? '${previousTransaction.description} (Discount: ${transaction.amount.toStringAsFixed(2)})'
              : 'Discount: ${transaction.amount.toStringAsFixed(2)}',
          category: previousTransaction.category.target,
          fromAccount: previousTransaction.fromAccount.target,
          createdAt: previousTransaction.createdAt,
          updatedAt: previousTransaction.updatedAt,
        );

        // Replace the previous transaction with the updated one
        processedTransactions[previousIndex] = updatedTransaction;

        // The discount transaction is not added to processedTransactions
      } else {
        // This is a regular transaction, add it to the processed list
        processedTransactions.add(transaction);
      }
    }

    return processedTransactions;
  }

  // Process global discounts that should be distributed across all items
  List<Transaction> _applyGlobalDiscounts(List<Transaction> inputTransactions) {
    // Find global discount transactions
    final globalDiscounts = inputTransactions
        .where(
            (tx) => _isDiscountCategory(tx.category.target, 'Overall discount'))
        .toList();

    if (globalDiscounts.isEmpty) return inputTransactions;

    // Calculate total discount amount
    double totalDiscountAmount =
        globalDiscounts.fold(0.0, (sum, tx) => sum + tx.amount);

    if (totalDiscountAmount <= 0) return inputTransactions;

    // Remove global discount transactions from the list
    final List<Transaction> remainingTransactions = inputTransactions
        .where((tx) =>
            !_isDiscountCategory(tx.category.target, 'Overall discount'))
        .toList();

    // Get regular transactions to apply discounts to (non-discount categories)
    final regularTransactions = remainingTransactions.where((tx) {
      final category = tx.category.target;
      return !_isDiscountCategory(category, 'Discount for item') &&
          !_isDiscountCategory(category, 'Overall discount');
    }).toList();

    if (regularTransactions.isEmpty) return remainingTransactions;

    // Calculate sum of all regular transaction amounts
    final double totalRegularAmount =
        regularTransactions.fold(0.0, (sum, tx) => sum + tx.amount);

    if (totalRegularAmount <= 0) return remainingTransactions;

    // Create new transactions with proportionally applied discounts
    final List<Transaction> updatedTransactions = [];

    for (final tx in remainingTransactions) {
      final category = tx.category.target;

      if (!_isDiscountCategory(category, 'Discount for item') &&
          !_isDiscountCategory(category, 'Overall discount')) {
        // Calculate proportional discount for this transaction
        final proportion = tx.amount / totalRegularAmount;
        final discountForItem = totalDiscountAmount * proportion;

        // Create updated transaction with discount applied
        final updatedTransaction = Transaction(
          id: tx.id,
          title: tx.title,
          amount: tx.amount - discountForItem,
          date: tx.date,
          description: tx.description != null
              ? '${tx.description} (Overall discount: -${discountForItem.toStringAsFixed(2)})'
              : 'Overall discount: -${discountForItem.toStringAsFixed(2)}',
          category: tx.category.target,
          fromAccount: tx.fromAccount.target,
          createdAt: tx.createdAt,
          updatedAt: tx.updatedAt,
        );

        updatedTransactions.add(updatedTransaction);
      } else {
        // Keep non-regular transactions as they are
        updatedTransactions.add(tx);
      }
    }

    return updatedTransactions;
  }

  // Calculate total expenses and check for discrepancies
  void _calculateTotalExpenses() {
    final sum = state.transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );

    // Round to 2 decimal places for display
    final totalExpenses = double.parse(sum.toStringAsFixed(2));

    // Check if total matches the receipt
    String? warningMessage;
    if (totalExpenses != state.receiptTotalAmount) {
      final diff = (totalExpenses - state.receiptTotalAmount).abs();
      if (diff > 0.01) {
        // Allow for tiny rounding differences
        warningMessage =
            'Total amount (${totalExpenses.toStringAsFixed(2)}) differs from receipt (${state.receiptTotalAmount.toStringAsFixed(2)})';
      }
    }

    emit(state.copyWith(
      totalExpenses: totalExpenses,
      warningMessage: warningMessage,
    ));
  }

  // Remove a transaction and recalculate total
  void removeTransaction(int index) {
    final updatedTransactions = List<Transaction>.from(state.transactions);
    updatedTransactions.removeAt(index);

    emit(state.copyWith(transactions: updatedTransactions));
    _calculateTotalExpenses();
  }

  // Update a single transaction
  void updateTransaction(int index, Transaction transaction) {
    if (index >= 0 && index < state.transactions.length) {
      final updatedTransactions = List<Transaction>.from(state.transactions);
      updatedTransactions[index] = transaction;

      emit(state.copyWith(transactions: updatedTransactions));
      _calculateTotalExpenses();
    }
  }

  // Set the selected account and apply to all transactions
  void setSelectedAccount(Account? account) {
    if (account != null) {
      emit(state.copyWith(selectedAccount: account));
      _applyAccountToAllTransactions();
    }
  }

  // Set the selected date and apply to all transactions
  void setSelectedDate(DateTime date) {
    emit(state.copyWith(selectedDate: date));
    _applyDateToAllTransactions();
  }

  // Apply the selected account to all transactions
  void _applyAccountToAllTransactions() {
    if (state.selectedAccount == null) return;

    final updatedTransactions = state.transactions.map((transaction) {
      return Transaction(
        id: transaction.id,
        title: transaction.title,
        amount: transaction.amount,
        date: transaction.date,
        description: transaction.description,
        category: transaction.category.target,
        fromAccount: state.selectedAccount,
        createdAt: transaction.createdAt,
        updatedAt: transaction.updatedAt,
        metadata: transaction.metadata,
      );
    }).toList();

    emit(state.copyWith(transactions: updatedTransactions));
  }

  // Apply the selected date to all transactions
  void _applyDateToAllTransactions() {
    final updatedTransactions = state.transactions.map((transaction) {
      return transaction.copyWith(date: state.selectedDate);
    }).toList();

    emit(state.copyWith(transactions: updatedTransactions));
  }

  // Group transactions by category and merge them
  void mergeTransactionsByCategory() {
    // Store current state for potential restoration
    final currentTransactions = List<Transaction>.from(state.transactions);

    // Group by category
    final Map<int?, double> categoryTotals = {};
    final Map<int?, Category?> categoryMap = {};

    for (var transaction in state.transactions) {
      final categoryId = transaction.category.target?.id;
      final category = transaction.category.target;

      if (categoryId != null) {
        categoryTotals[categoryId] =
            (categoryTotals[categoryId] ?? 0.0) + transaction.amount;
        categoryMap[categoryId] = category;
      }
    }

    // Create merged transactions
    final mergedTransactions = categoryTotals.entries.map((entry) {
      final categoryId = entry.key;
      final totalAmount = entry.value;
      final category = categoryMap[categoryId];

      return Transaction(
        title: '${category?.title ?? 'Unknown'} at ${state.storeName}',
        amount: double.parse(totalAmount.toStringAsFixed(2)),
        date: state.selectedDate,
        category: category,
        fromAccount: state.selectedAccount,
      );
    }).toList();

    // The current transactions become the new original transactions if we're applying merging
    // This ensures that if discounts were already applied, the merged transactions
    // will become the new base for any further operations
    emit(state.copyWith(
      transactions: mergedTransactions,
      // If discounts were applied, keep track of the pre-merge transactions as the original state
      // Otherwise, use the current originalTransactions
      originalTransactions: state.discountsApplied
          ? currentTransactions
          : state.originalTransactions,
    ));
    _calculateTotalExpenses();
  }
}
