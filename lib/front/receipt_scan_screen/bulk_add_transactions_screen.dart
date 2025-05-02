import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/receipt_scan_screen/cubit/bulk_transactions_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';

/// Screen for reviewing and adding transactions from a receipt scan.
/// Allows users to modify, merge, or apply discounts to transactions
/// before saving them to the app.
class BulkAddTransactionsScreen extends StatelessWidget {
  final String transactionName;
  final DateTime date;
  final double totalExpensesFromReceipt;
  final List<Transaction> transactions;

  const BulkAddTransactionsScreen({
    Key? key,
    required this.transactionName,
    required this.date,
    required this.totalExpensesFromReceipt,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BulkTransactionsCubit(
        transactions: transactions,
        storeName: transactionName,
        receiptDate: date,
        receiptTotalAmount: totalExpensesFromReceipt,
      ),
      child: const _BulkAddTransactionsView(),
    );
  }
}

/// Main view for the BulkAddTransactionsScreen
/// Separated from the provider to maintain clean architecture
class _BulkAddTransactionsView extends StatelessWidget {
  const _BulkAddTransactionsView({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Review Receipt Items'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Receipt Info Card
          const ReceiptInfoCard(),

          // Divider
          const Divider(height: 1),

          // Transaction List Header
          const TransactionListHeader(),

          // Transactions List
          Expanded(
            child: BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
              buildWhen: (previous, current) =>
                  previous.transactions != current.transactions,
              builder: (context, state) {
                if (state.transactions.isEmpty) {
                  return const EmptyTransactionsList();
                } else {
                  return const TransactionsList();
                }
              },
            ),
          ),

          // Bottom Actions Bar
          const BottomActionsBar(),
        ],
      ),
    );
  }
}

/// Widget that displays receipt information and provides controls
/// to manipulate the transaction date, account, and discount application
class ReceiptInfoCard extends StatelessWidget {
  const ReceiptInfoCard({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
      buildWhen: (previous, current) =>
          previous.selectedDate != current.selectedDate ||
          previous.totalExpenses != current.totalExpenses ||
          previous.warningMessage != current.warningMessage ||
          previous.selectedAccount != current.selectedAccount ||
          previous.discountsApplied != current.discountsApplied,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(AppStyle.paddingMedium),
          color: AppStyle.cardColor,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Store name
              Row(
                children: [
                  Icon(Icons.store, color: AppStyle.primaryColor),
                  SizedBox(width: AppStyle.paddingSmall),
                  Expanded(
                    child: Text(
                      state.storeName,
                      style: AppStyle.titleStyle,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
              SizedBox(height: AppStyle.paddingSmall),

              // Date picker and total info
              Row(
                children: [
                  // Date picker
                  Expanded(
                    child: InkWell(
                      onTap: () => _selectDate(context, state.selectedDate),
                      child: Row(
                        children: [
                          Icon(Icons.calendar_today,
                              size: 16, color: AppStyle.textColorSecondary),
                          SizedBox(width: AppStyle.paddingSmall),
                          Text(
                            DateFormat.yMMMd().format(state.selectedDate),
                            style: AppStyle.bodyText,
                          ),
                        ],
                      ),
                    ),
                  ),

                  // Total amount
                  Container(
                    padding: EdgeInsets.symmetric(
                      horizontal: AppStyle.paddingMedium,
                      vertical: AppStyle.paddingSmall / 2,
                    ),
                    decoration: BoxDecoration(
                      color: AppStyle.primaryColor.withOpacity(0.1),
                      borderRadius:
                          BorderRadius.circular(AppStyle.borderRadiusSmall),
                    ),
                    child: Text(
                      'Total: ${state.totalExpenses.toStringAsFixed(2)}',
                      style: AppStyle.subtitleStyle.copyWith(
                        color: AppStyle.primaryColor,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),

              // Warning message if totals don't match
              if (state.warningMessage != null)
                Padding(
                  padding: const EdgeInsets.only(top: AppStyle.paddingSmall),
                  child: Row(
                    children: [
                      Icon(Icons.warning_amber_rounded,
                          color: Colors.amber, size: 16),
                      SizedBox(width: AppStyle.paddingSmall),
                      Expanded(
                        child: Text(
                          state.warningMessage!,
                          style: AppStyle.captionStyle
                              .copyWith(color: Colors.amber[800]),
                        ),
                      ),
                    ],
                  ),
                ),

              // Account dropdown
              Padding(
                padding: const EdgeInsets.only(top: AppStyle.paddingMedium),
                child: AccountDropdown(
                  selectedAccount: state.selectedAccount,
                  onAccountChanged: (account) {
                    if (account != null) {
                      context
                          .read<BulkTransactionsCubit>()
                          .setSelectedAccount(account);
                    }
                  },
                ),
              ),

              // Discounts button
              Padding(
                padding: const EdgeInsets.only(top: AppStyle.paddingMedium),
                child: ElevatedButton(
                  onPressed: () {
                    if (state.discountsApplied) {
                      context
                          .read<BulkTransactionsCubit>()
                          .restoreOriginalTransactions();
                    } else {
                      context.read<BulkTransactionsCubit>().processDiscounts();
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryColor,
                    foregroundColor: Colors.white,
                  ),
                  child: Text(
                    state.discountsApplied
                        ? 'Remove Discounts'
                        : 'Apply Discounts',
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // Helper method to show date picker
  Future<void> _selectDate(BuildContext context, DateTime initialDate) async {
    final DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && context.mounted) {
      context.read<BulkTransactionsCubit>().setSelectedDate(pickedDate);
    }
  }
}

/// Header section for the transaction list
class TransactionListHeader extends StatelessWidget {
  const TransactionListHeader({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
      buildWhen: (previous, current) =>
          previous.transactions.length != current.transactions.length,
      builder: (context, state) {
        return Container(
          padding: const EdgeInsets.all(AppStyle.paddingMedium),
          color: AppStyle.backgroundColor,
          child: Row(
            children: [
              Text(
                'Items (${state.transactions.length})',
                style: AppStyle.subtitleStyle
                    .copyWith(fontWeight: FontWeight.bold),
              ),
              Spacer(),
              if (state.transactions.length > 1)
                TextButton.icon(
                  onPressed: () => context
                      .read<BulkTransactionsCubit>()
                      .mergeTransactionsByCategory(),
                  icon: Icon(Icons.merge_type, size: 16),
                  label: Text('Merge Similar'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppStyle.primaryColor,
                    padding: EdgeInsets.symmetric(
                      horizontal: AppStyle.paddingMedium,
                      vertical: AppStyle.paddingSmall / 2,
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

/// Widget showing an empty state when no transactions are available
class EmptyTransactionsList extends StatelessWidget {
  const EmptyTransactionsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.receipt_long,
            size: 64,
            color: AppStyle.textColorSecondary.withOpacity(0.5),
          ),
          SizedBox(height: AppStyle.paddingMedium),
          Text(
            'No items found in this receipt',
            style: AppStyle.bodyText.copyWith(
              color: AppStyle.textColorSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// List showing all transactions from the receipt
/// Modified to read transactions directly from state
class TransactionsList extends StatelessWidget {
  const TransactionsList({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
      buildWhen: (previous, current) =>
          previous.transactions != current.transactions,
      builder: (context, state) {
        return ListView.builder(
          itemCount: state.transactions.length,
          padding: EdgeInsets.zero,
          itemBuilder: (context, index) {
            return TransactionListItem(
              transaction: state.transactions[index],
              index: index,
            );
          },
        );
      },
    );
  }
}

/// Individual transaction list item with edit/delete capabilities
class TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final int index;

  const TransactionListItem({
    Key? key,
    required this.transaction,
    required this.index,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final category = transaction.category.target;

    return Dismissible(
      key: ValueKey(transaction.hashCode),
      background: Container(
        color: AppStyle.expenseColor,
        alignment: Alignment.centerRight,
        padding: EdgeInsets.only(right: AppStyle.paddingLarge),
        child: Icon(Icons.delete_outline, color: Colors.white),
      ),
      direction: DismissDirection.endToStart,
      confirmDismiss: (_) => _confirmDelete(context),
      onDismissed: (_) =>
          context.read<BulkTransactionsCubit>().removeTransaction(index),
      child: ListTile(
        leading: Container(
          width: 40,
          height: 40,
          decoration: BoxDecoration(
            color: Color(category?.colorValue ?? 0xFF9E9E9E).withOpacity(0.2),
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
          child: Icon(
            category?.icon ?? Icons.category,
            color: Color(category?.colorValue ?? 0xFF9E9E9E),
            size: 20,
          ),
        ),
        title: Text(
          transaction.title,
          style: AppStyle.bodyText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        subtitle: Text(
          category?.title ?? 'Uncategorized',
          style: AppStyle.captionStyle,
        ),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              transaction.amount.toStringAsFixed(2),
              style: AppStyle.subtitleStyle.copyWith(
                fontWeight: FontWeight.bold,
                color: transaction.isIncome
                    ? AppStyle.incomeColor
                    : AppStyle.expenseColor,
              ),
            ),
            SizedBox(width: AppStyle.paddingMedium),
            Icon(Icons.chevron_right, color: AppStyle.textColorSecondary),
          ],
        ),
        onTap: () => _editTransaction(context),
      ),
    );
  }

  Future<bool> _confirmDelete(BuildContext context) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Delete Item?', style: AppStyle.titleStyle),
        content: Text(
          'Are you sure you want to remove this item from the receipt?',
          style: AppStyle.bodyText,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
            style: TextButton.styleFrom(
                foregroundColor: AppStyle.textColorSecondary),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppStyle.expenseColor,
              foregroundColor: Colors.white,
            ),
            child: Text('Delete'),
          ),
        ],
      ),
    );

    return result ?? false;
  }

  Future<void> _editTransaction(BuildContext context) async {
    final result = await Navigator.push<TransactionResult>(
      context,
      MaterialPageRoute(
        builder: (context) => TransactionFormScreen(transaction: transaction),
      ),
    );

    if (result != null && context.mounted) {
      context
          .read<BulkTransactionsCubit>()
          .updateTransaction(index, result.transaction);
    }
  }
}

/// Bottom action bar with save and cancel buttons
class BottomActionsBar extends StatelessWidget {
  const BottomActionsBar({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
      buildWhen: (previous, current) =>
          previous.transactions != current.transactions,
      builder: (context, state) {
        return Container(
          padding: EdgeInsets.all(AppStyle.paddingMedium),
          decoration: BoxDecoration(
            color: Colors.white,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 4,
                offset: Offset(0, -2),
              ),
            ],
          ),
          child: Row(
            children: [
              // Cancel button
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppStyle.textColorSecondary,
                    side: BorderSide(
                        color: AppStyle.textColorSecondary.withOpacity(0.3)),
                    padding:
                        EdgeInsets.symmetric(vertical: AppStyle.paddingMedium),
                  ),
                  child: Text('Cancel'),
                ),
              ),
              SizedBox(width: AppStyle.paddingMedium),

              // Save button
              Expanded(
                flex: 2,
                child: ElevatedButton(
                  onPressed: state.transactions.isEmpty
                      ? null
                      : () {
                          final processedTransactions =
                              List<Transaction>.from(state.transactions);
                          Navigator.pop(context, processedTransactions);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryColor,
                    foregroundColor: Colors.white,
                    padding:
                        EdgeInsets.symmetric(vertical: AppStyle.paddingMedium),
                    disabledBackgroundColor:
                        AppStyle.primaryColor.withOpacity(0.3),
                  ),
                  child: Text('Save Transactions'),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
