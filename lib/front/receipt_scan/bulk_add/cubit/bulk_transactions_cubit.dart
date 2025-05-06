import 'package:equatable/equatable.dart';
import 'package:flutter/foundation.dart' as foundation; // For listEquals
import 'package:flutter/material.dart'; // For Color/IconData
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // For DateFormat
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/account_repository.dart'; // Import repo
import 'package:money_owl/backend/repositories/category_repository.dart'; // Import repo
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/transactions_screen/viewmodel/transaction_viewmodel.dart'; // Import ViewModel

part 'bulk_transactions_state.dart';

class BulkTransactionsCubit extends Cubit<BulkTransactionsState> {
  // --- Add Repositories ---
  final CategoryRepository _categoryRepository;
  final AccountRepository _accountRepository;
  List<Category> allCategories = []; // Cache categories
  List<Account> allAccounts = []; // Cache accounts

  BulkTransactionsCubit({
    required List<Transaction> transactions,
    required String storeName,
    required DateTime receiptDate,
    required double receiptTotalAmount,
    // --- Inject Repositories ---
    required CategoryRepository categoryRepository,
    required AccountRepository accountRepository,
  })  : _categoryRepository = categoryRepository, // Initialize repo
        _accountRepository = accountRepository, // Initialize repo
        super(BulkTransactionsState(
          transactions: transactions,
          originalTransactions: List.from(transactions),
          selectedDate: receiptDate,
          storeName: storeName,
          receiptTotalAmount: receiptTotalAmount,
          selectedAccount: Defaults().defaultAccount,
          loadingStatus: LoadingStatus.initial, // Initialize status
        )) {
    _initializeAndMap(); // Load dependencies and perform initial mapping
  }

  // --- New method to load dependencies and map ---
  Future<void> _initializeAndMap() async {
    emit(state.copyWith(loadingStatus: LoadingStatus.loading)); // Set loading
    try {
      // Fetch all categories and accounts once
      allCategories = await _categoryRepository.getAll();
      allAccounts = await _accountRepository.getAll();

      // Apply defaults which might modify transactions
      _applyAccountToAllTransactionsInternal();
      _applyDateToAllTransactionsInternal();

      // Perform initial mapping
      _mapAndEmitTransactions();
      _calculateTotalExpenses(); // Calculate initial total

      emit(state.copyWith(loadingStatus: LoadingStatus.success)); // Set success
    } catch (e) {
      // Basic error handling, consider more specific error states if needed
      emit(state.copyWith(loadingStatus: LoadingStatus.failure)); // Set failure
      // Optionally log the error: print('Error initializing BulkTransactionsCubit: $e');
    }
  }

  // --- New Mapping Method ---
  List<TransactionViewModel> _mapTransactionsToViewModels(
      List<Transaction> rawTransactions) {
    final List<TransactionViewModel> viewModels = [];
    final dateFormat = DateFormat.Md(); // Or your preferred format
    // Use cached lists for lookup
    final accountMap = {for (var acc in allAccounts) acc.id: acc};
    final categoryMap = {for (var cat in allCategories) cat.id: cat};

    for (final tx in rawTransactions) {
      // Use targetId for lookup
      final category = categoryMap[tx.category.targetId];
      final account = accountMap[tx.fromAccount.targetId];

      final displayAmount =
          '${tx.isIncome ? '+' : ''}${tx.amount.toStringAsFixed(2)} ${account?.currencySymbolOrCurrency ?? Defaults().defaultCurrencySymbol}';
      final categoryName = category?.title ?? 'Uncategorized';
      final categoryColor = category?.color ?? Colors.grey;
      final categoryIcon = category?.icon ?? Icons.question_mark;
      final accountName = account?.name ?? 'Unknown Account';

      viewModels.add(TransactionViewModel(
        id: tx.id, // Use the raw transaction's ID (might be 0)
        title: tx.title,
        displayAmount: displayAmount,
        categoryName: categoryName,
        categoryColor: categoryColor,
        categoryIcon: categoryIcon,
        displayDate: dateFormat.format(tx.date),
        date: tx.date,
        isIncome: tx.isIncome,
        accountName: accountName,
      ));
    }
    return viewModels;
  }
  // --- End New Mapping Method ---

  // --- New method to centralize mapping and emitting ---
  void _mapAndEmitTransactions() {
    final viewModels = _mapTransactionsToViewModels(state.transactions);
    emit(state.copyWith(displayedTransactions: viewModels));
  }
  // --- End New method ---

  // --- Update existing methods to call mapping ---

  void processDiscounts() {
    if (state.discountsApplied) return; // Avoid applying twice

    List<Transaction> processed = List.from(state.transactions);
    processed = _applyItemDiscounts(processed);
    processed = _applyGlobalDiscounts(processed);

    emit(state.copyWith(
      transactions: processed,
      discountsApplied: true,
    ));
    _mapAndEmitTransactions(); // Remap after processing
    _calculateTotalExpenses();
  }

  void restoreOriginalTransactions() {
    emit(state.copyWith(
      transactions: List.from(state.originalTransactions),
      discountsApplied: false, // Reset flag
    ));
    _mapAndEmitTransactions(); // Remap after restoring
    _calculateTotalExpenses();
  }

  // Helper: Check if category matches discount type
  bool _isCategoryName(Category? category, String discountType) {
    return category?.title == discountType;
  }

  // Apply item discounts (Internal logic remains similar, uses copyWith)
  List<Transaction> _applyItemDiscounts(List<Transaction> inputTransactions) {
    final List<Transaction> processedTransactions = [];
    for (int i = 0; i < inputTransactions.length; i++) {
      final transaction = inputTransactions[i];
      final category = allCategories.firstWhere(
          (c) => c.id == transaction.category.targetId,
          orElse: () => Defaults().defaultCategory);

      if (_isCategoryName(category, 'Discount for item')) {
        if (processedTransactions.isEmpty) {
          processedTransactions.add(transaction);
          continue;
        }

        final previousIndex = processedTransactions.length - 1;
        final previousTransaction = processedTransactions[previousIndex];

        // Use copyWith to update amount and description
        final newAmount = previousTransaction.amount +
            transaction.amount.abs(); // Add discount amount (abs)
        final discountDesc =
            ' (Discount: -${transaction.amount.abs().toStringAsFixed(2)})'; // Show discount as negative
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

  // Apply global discounts (Internal logic remains similar, uses copyWith)
  List<Transaction> _applyGlobalDiscounts(List<Transaction> inputTransactions) {
    // --- FIX: Fetch category using cached map ---
    final globalDiscounts = inputTransactions.where((tx) {
      final category = allCategories.firstWhere(
          (c) => c.id == tx.category.targetId,
          orElse: () => Defaults().defaultCategory);
      return _isCategoryName(category, 'Overall discount');
    }).toList();
    // --- END FIX ---

    if (globalDiscounts.isEmpty) return inputTransactions;

    double totalDiscountAmount =
        globalDiscounts.fold(0.0, (sum, tx) => sum + tx.amount.abs());

    if (totalDiscountAmount <= 0) return inputTransactions;

    // --- FIX: Fetch category using cached map ---
    final List<Transaction> remainingTransactions =
        inputTransactions.where((tx) {
      final category = allCategories.firstWhere(
          (c) => c.id == tx.category.targetId,
          orElse: () => Defaults().defaultCategory);
      return !_isCategoryName(category, 'Overall discount');
    }).toList();

    final regularTransactions = remainingTransactions.where((tx) {
      final category = allCategories.firstWhere(
          (c) => c.id == tx.category.targetId,
          orElse: () => Defaults().defaultCategory);
      return !_isCategoryName(category, 'Discount for item') &&
          !_isCategoryName(category, 'Overall discount');
    }).toList();
    // --- END FIX ---

    if (regularTransactions.isEmpty) return remainingTransactions;

    final double totalRegularAmount =
        regularTransactions.fold(0.0, (sum, tx) => sum + tx.amount.abs());

    if (totalRegularAmount <= 0) return remainingTransactions;

    final List<Transaction> updatedTransactions = [];
    for (final tx in remainingTransactions) {
      // --- FIX: Fetch category using cached map ---
      final category = allCategories.firstWhere(
          (c) => c.id == tx.category.targetId,
          orElse: () => Defaults().defaultCategory);
      // --- END FIX ---

      if (!_isCategoryName(category, 'Discount for item') &&
          !_isCategoryName(category, 'Overall discount')) {
        final proportion = tx.amount.abs() / totalRegularAmount;
        final discountForItem = totalDiscountAmount * proportion;
        final newAmount = tx.amount + discountForItem; // Add discount amount
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
    final total = state.transactions
        .fold<double>(0.0, (sum, tx) => sum + (tx.amount)); // Only sum expenses
    emit(state.copyWith(calculatedTotalExpenses: total));
  }

  void removeTransaction(int index) {
    if (index >= 0 && index < state.transactions.length) {
      final updatedTransactions = List<Transaction>.from(state.transactions)
        ..removeAt(index);
      // Also update original if needed, or handle restore logic carefully
      final updatedOriginal =
          List<Transaction>.from(state.originalTransactions);
      if (index < updatedOriginal.length) {
        // Check bounds for original
        updatedOriginal.removeAt(index);
      }

      emit(state.copyWith(
        transactions: updatedTransactions,
        originalTransactions:
            updatedOriginal, // Keep original in sync if removing permanently
      ));
      _mapAndEmitTransactions(); // Remap after removing
      _calculateTotalExpenses();
    }
  }

  void updateTransaction(int index, Transaction transaction) {
    if (index >= 0 && index < state.transactions.length) {
      final updatedTransactions = List<Transaction>.from(state.transactions);
      // Apply bulk date and account ID
      updatedTransactions[index] = transaction.copyWith(
        date: state.selectedDate,
        fromAccountId:
            state.selectedAccount?.id ?? Defaults().defaultAccount.id,
      );

      emit(state.copyWith(transactions: updatedTransactions));
      _mapAndEmitTransactions(); // Remap after updating
      _calculateTotalExpenses();
    }
  }

  void setSelectedAccount(Account? account) {
    if (account != null) {
      emit(state.copyWith(selectedAccount: account));
      _applyAccountToAllTransactionsInternal(); // Apply internally
      _mapAndEmitTransactions(); // Remap after applying
    }
  }

  void setSelectedDate(DateTime date) {
    emit(state.copyWith(selectedDate: date));
    _applyDateToAllTransactionsInternal(); // Apply internally
    _mapAndEmitTransactions(); // Remap after applying
  }

  // Internal method to apply account without emitting intermediate state
  void _applyAccountToAllTransactionsInternal() {
    if (state.selectedAccount == null) return;
    final accountId = state.selectedAccount!.id;

    final updatedTransactions = state.transactions.map((transaction) {
      return transaction.copyWith(fromAccountId: accountId);
    }).toList();

    // Update the raw list directly in the state (will be mapped later)
    // Use copyWith to ensure state immutability
    emit(state.copyWith(transactions: updatedTransactions));
  }

  // Internal method to apply date without emitting intermediate state
  void _applyDateToAllTransactionsInternal() {
    final updatedTransactions = state.transactions.map((transaction) {
      return transaction.copyWith(date: state.selectedDate);
    }).toList();
    // Update the raw list directly in the state (will be mapped later)
    emit(state.copyWith(transactions: updatedTransactions));
  }

  void mergeTransactionsByCategory() {
    final Map<int?, double> categoryTotals = {};
    final Map<int?, Category?> categoryMap = {};
    final Map<int?, List<Map<String, dynamic>?>> metadataMap = {};

    for (var transaction in state.transactions) {
      final categoryId = transaction.category.targetId;
      // --- FIX: Fetch category using cached map ---
      final category = allCategories.firstWhere((c) => c.id == categoryId,
          orElse: () => Defaults().defaultCategory);
      // --- END FIX ---

      categoryTotals[categoryId] =
          (categoryTotals[categoryId] ?? 0.0) + transaction.amount;
      // --- FIX: Remove redundant null check ---
      if (!categoryMap.containsKey(categoryId)) {
        // --- END FIX ---
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
    ));
    _mapAndEmitTransactions(); // Remap after merging
    _calculateTotalExpenses();
  }

  // listEquals helper remains the same
  bool listEquals<T>(List<T>? a, List<T>? b) {
    return foundation.listEquals(a, b);
  }
}
