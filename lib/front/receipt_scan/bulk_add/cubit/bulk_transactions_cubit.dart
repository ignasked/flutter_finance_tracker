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
    _applyAccountToAllTransactions();
    _applyDateToAllTransactions();
    _calculateTotalExpenses();
  }

  void processDiscounts() {
    if (state.discountsApplied) {
      restoreOriginalTransactions();
    }

    List<Transaction> originalTransactions = List.from(state.transactions);
    var transactions = _applyItemDiscounts(List.from(state.transactions));

    emit(state.copyWith(
      transactions: transactions,
      originalTransactions: originalTransactions,
      discountsApplied: true,
    ));

    _calculateTotalExpenses();
  }

  void restoreOriginalTransactions() {
    emit(state.copyWith(
      transactions: List.from(state.originalTransactions),
      discountsApplied: false,
    ));
    _calculateTotalExpenses();
  }

  bool _isDiscountCategory(Category? category, String discountType) {
    if (category == null) return false;
    return category.title.toLowerCase() == discountType.toLowerCase() &&
        category.type == TransactionType.income;
  }

  List<Transaction> _applyItemDiscounts(List<Transaction> inputTransactions) {
    final List<Transaction> processedTransactions = [];
    for (int i = 0; i < inputTransactions.length; i++) {
      final transaction = inputTransactions[i];
      final category = transaction.category.target;

      if (_isDiscountCategory(category, 'Discount for item')) {
        if (processedTransactions.isEmpty) {
          processedTransactions.add(transaction);
          continue;
        }

        final previousIndex = processedTransactions.length - 1;
        final previousTransaction = processedTransactions[previousIndex];

        final newAmount = transaction.amount > 0
            ? previousTransaction.amount - transaction.amount
            : previousTransaction.amount + transaction.amount;
        final discountDesc =
            ' (Discount: ${transaction.amount.toStringAsFixed(2)})';
        final newDescription =
            (previousTransaction.description ?? '') + discountDesc;

        final updatedTransaction = previousTransaction.copyWith(
          amount: newAmount,
          description: newDescription,
        );

        processedTransactions[previousIndex] = updatedTransaction;
      } else {
        processedTransactions.add(transaction);
      }
    }
    return processedTransactions;
  }

  List<Transaction> _applyGlobalDiscounts(List<Transaction> inputTransactions) {
    final globalDiscounts = inputTransactions
        .where(
            (tx) => _isDiscountCategory(tx.category.target, 'Overall discount'))
        .toList();

    if (globalDiscounts.isEmpty) return inputTransactions;

    double totalDiscountAmount =
        globalDiscounts.fold(0.0, (sum, tx) => sum + tx.amount.abs());

    if (totalDiscountAmount <= 0) return inputTransactions;

    final List<Transaction> remainingTransactions = inputTransactions
        .where((tx) =>
            !_isDiscountCategory(tx.category.target, 'Overall discount'))
        .toList();

    final regularTransactions = remainingTransactions.where((tx) {
      final category = tx.category.target;
      return !_isDiscountCategory(category, 'Discount for item') &&
          !_isDiscountCategory(category, 'Overall discount');
    }).toList();

    if (regularTransactions.isEmpty) return remainingTransactions;

    final double totalRegularAmount =
        regularTransactions.fold(0.0, (sum, tx) => sum + tx.amount.abs());

    if (totalRegularAmount <= 0) return remainingTransactions;

    final List<Transaction> updatedTransactions = [];
    for (final tx in remainingTransactions) {
      final category = tx.category.target;

      if (!_isDiscountCategory(category, 'Discount for item') &&
          !_isDiscountCategory(category, 'Overall discount')) {
        final proportion = tx.amount.abs() / totalRegularAmount;
        final discountForItem = totalDiscountAmount * proportion;
        final newAmount = tx.amount + discountForItem;
        final discountDesc =
            ' (Overall discount: +${discountForItem.toStringAsFixed(2)})';
        final newDescription = (tx.description ?? '') + discountDesc;

        final updatedTransaction = tx.copyWith(
          amount: newAmount,
          description: newDescription,
        );
        updatedTransactions.add(updatedTransaction);
      } else {
        updatedTransactions.add(tx);
      }
    }
    return updatedTransactions;
  }

  void _calculateTotalExpenses() {
    final sum = state.transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );

    final totalExpenses = double.parse(sum.toStringAsFixed(2));

    String? warningMessage;
    if (totalExpenses != state.receiptTotalAmount) {
      final diff = (totalExpenses - state.receiptTotalAmount).abs();
      if (diff > 0.01) {
        warningMessage =
            'Total amount (${totalExpenses.toStringAsFixed(2)}) differs from receipt (${state.receiptTotalAmount.toStringAsFixed(2)})';
      }
    }

    emit(state.copyWith(
      totalExpenses: totalExpenses,
      warningMessage: warningMessage,
    ));
  }

  void removeTransaction(int index) {
    final updatedTransactions = List<Transaction>.from(state.transactions);
    updatedTransactions.removeAt(index);

    emit(state.copyWith(transactions: updatedTransactions));
    _calculateTotalExpenses();
  }

  void updateTransaction(int index, Transaction transaction) {
    if (index >= 0 && index < state.transactions.length) {
      final updatedTransactions = List<Transaction>.from(state.transactions);
      updatedTransactions[index] = transaction.copyWith(
        date: state.selectedDate,
        fromAccountId:
            state.selectedAccount?.id ?? Defaults().defaultAccount.id,
      );

      emit(state.copyWith(transactions: updatedTransactions));
      _calculateTotalExpenses();
    }
  }

  void setSelectedAccount(Account? account) {
    if (account != null) {
      emit(state.copyWith(selectedAccount: account));
      _applyAccountToAllTransactions();
    }
  }

  void setSelectedDate(DateTime date) {
    emit(state.copyWith(selectedDate: date));
    _applyDateToAllTransactions();
  }

  void _applyAccountToAllTransactions() {
    if (state.selectedAccount == null) return;
    final accountId = state.selectedAccount!.id;

    final updatedTransactions = state.transactions.map((transaction) {
      return transaction.copyWith(fromAccountId: accountId);
    }).toList();

    if (!listEquals(state.transactions, updatedTransactions)) {
      emit(state.copyWith(transactions: updatedTransactions));
    }
  }

  void _applyDateToAllTransactions() {
    final updatedTransactions = state.transactions.map((transaction) {
      return transaction.copyWith(date: state.selectedDate);
    }).toList();

    if (!listEquals(state.transactions, updatedTransactions)) {
      emit(state.copyWith(transactions: updatedTransactions));
    }
  }

  void mergeTransactionsByCategory() {
    final Map<int?, double> categoryTotals = {};
    final Map<int?, Category?> categoryMap = {};
    final Map<int?, List<Map<String, dynamic>?>> metadataMap = {};

    for (var transaction in state.transactions) {
      final categoryId = transaction.category.targetId;
      final category = transaction.category.target;

      categoryTotals[categoryId] =
          (categoryTotals[categoryId] ?? 0.0) + transaction.amount;
      if (categoryId != null && !categoryMap.containsKey(categoryId)) {
        categoryMap[categoryId] = category;
      }
      metadataMap.putIfAbsent(categoryId, () => []).add(transaction.metadata);
    }

    final mergedTransactions = categoryTotals.entries.map((entry) {
      final categoryId = entry.key;
      final totalAmount = entry.value;
      final category = categoryMap[categoryId];
      final combinedMetadata = {'mergedItems': metadataMap[categoryId]};

      return Transaction.createWithIds(
        title: '${category?.title ?? 'Unknown'} at ${state.storeName}',
        amount: double.parse(totalAmount.toStringAsFixed(2)),
        date: state.selectedDate,
        categoryId: categoryId ?? Defaults().defaultCategory.id,
        fromAccountId:
            state.selectedAccount?.id ?? Defaults().defaultAccount.id,
        metadata: combinedMetadata,
      );
    }).toList();

    emit(state.copyWith(
      transactions: mergedTransactions,
      originalTransactions: List.from(state.transactions),
      discountsApplied: false,
    ));
    _calculateTotalExpenses();
  }

  bool listEquals<T>(List<T>? a, List<T>? b) {
    if (a == null) return b == null;
    if (b == null || a.length != b.length) return false;
    for (int i = 0; i < a.length; i++) {
      if (a[i] != b[i]) {
        return false;
      }
    }
    return true;
  }
}
