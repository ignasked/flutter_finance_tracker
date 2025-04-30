import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart'; // Import intl for date formatting
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/backend/utils/app_style.dart';

class TransactionListWidget extends StatelessWidget {
  final List<Transaction> transactions;
  final bool groupByMonth; // Add a flag to control grouping

  const TransactionListWidget({
    Key? key,
    required this.transactions,
    this.groupByMonth = false, // Default to no grouping
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Text('No transactions found for the selected period.',
            style: AppStyle.bodyText),
      );
    }

    if (groupByMonth) {
      // Group transactions by month
      Map<String, List<Transaction>> groupedTransactions =
          _groupTransactionsByMonth(transactions);

      return ListView(
        children: groupedTransactions.entries.map((entry) {
          final entriesDate = entry.key; // Format: YYYY-MM
          final monthTransactions = entry.value;
          // Parse the year and month for display
          final year = int.parse(entriesDate.split('-')[0]);
          final month = int.parse(entriesDate.split('-')[1]);
          final displayMonth =
              DateFormat('MMMM yyyy').format(DateTime(year, month));

          return ExpansionTile(
            title:
                Text(displayMonth, style: AppStyle.titleStyle), // Use AppStyle
            initiallyExpanded: true, // Keep tiles expanded by default
            childrenPadding: const EdgeInsets.only(
                left: AppStyle.paddingMedium), // Indent items
            children: monthTransactions.map((item) {
              return _buildTransactionItem(context, item);
            }).toList(),
          );
        }).toList(),
      );
    } else {
      // Flat list of transactions
      return ListView(
        children: transactions.map((item) {
          return _buildTransactionItem(context, item);
        }).toList(),
      );
    }
  }

  // Build a single transaction item
  Widget _buildTransactionItem(BuildContext context, Transaction item) {
    final category = item.category.target;
    final dateFormat = DateFormat('yyyy-MM-dd');

    return Dismissible(
      key: UniqueKey(),
      confirmDismiss: (direction) async {
        final txCubit = context.read<TransactionsCubit>();
        // No need for itemIndex here as we pass the item directly

        final result = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            // Use dialogContext
            return AlertDialog(
              title: const Text('Confirm Delete',
                  style: AppStyle.heading2), // Use AppStyle
              content: const Text(
                  'Are you sure you want to delete this transaction?',
                  style: AppStyle.bodyText), // Use AppStyle
              backgroundColor: AppStyle.cardColor,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AppStyle.paddingMedium),
              ),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel',
                      style: TextStyle(
                          color: AppStyle.textColorSecondary)), // Use AppStyle
                ),
                TextButton(
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete',
                      style: TextStyle(
                          color: AppStyle.expenseColor)), // Use AppStyle
                ),
              ],
            );
          },
        );

        if (!context.mounted) return false;

        if (result == true) {
          context.read<TransactionRepository>().remove(item.id);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${item.title} deleted.',
                  style: AppStyle.bodyText.copyWith(color: Colors.white)),
              backgroundColor: AppStyle.textColorPrimary,
            ),
          );
        }
        return false; // Return false to prevent default dismiss animation if cancelled
      },
      background: Container(
        color: AppStyle.expenseColor, // Use AppStyle expense color
        padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.paddingLarge), // Use AppStyle padding
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Card(
        margin: const EdgeInsets.symmetric(
            vertical: AppStyle.paddingSmall / 2,
            horizontal: AppStyle.paddingSmall / 2), // Add slight margin
        color: AppStyle.cardColor, // Use AppStyle card color
        elevation: 1.0, // Subtle elevation
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppStyle.paddingSmall), // Use AppStyle padding
        ),
        child: ListTile(
          leading: Icon(
            category?.icon ?? Icons.category, // Use default if null
            color: category?.color ??
                AppStyle.textColorSecondary, // Use AppStyle color
          ),
          title: Text(item.title, style: AppStyle.titleStyle), // Use AppStyle
          subtitle: Text(
            '${category?.title ?? 'Uncategorized'} | ${dateFormat.format(item.date)}', // Format date
            style: AppStyle.captionStyle, // Use AppStyle caption style
          ),
          trailing: Text(
            '${item.isIncome ? '+' : '-'} ${item.amountAndCurrencyString}',
            style: item.isIncome
                ? AppStyle.amountIncomeStyle
                : AppStyle.amountExpenseStyle, // Use AppStyle amount styles
          ),
          onTap: () async {
            final txCubit = context.read<TransactionsCubit>();
            final itemIndex = transactions
                .indexOf(item); // Still need index for editing result

            final TransactionResult? transactionFormResult =
                await Navigator.push<TransactionResult>(
              context,
              MaterialPageRoute(
                builder: (context) => TransactionFromScreen(
                  transaction: item,
                  index: itemIndex,
                ),
              ),
            );

            if (!context.mounted) return;

            if (transactionFormResult != null) {
              txCubit.handleTransactionFormResult(transactionFormResult);
            }
          },
        ),
      ),
    );
  }

  // Group transactions by month
  Map<String, List<Transaction>> _groupTransactionsByMonth(
      List<Transaction> transactions) {
    Map<String, List<Transaction>> grouped = {};
    // Sort transactions by date descending before grouping
    transactions.sort((a, b) => b.date.compareTo(a.date));

    for (var transaction in transactions) {
      final monthYear = DateFormat('yyyy-MM')
          .format(transaction.date); // Use DateFormat for consistency
      if (grouped.containsKey(monthYear)) {
        grouped[monthYear]!.add(transaction);
      } else {
        grouped[monthYear] = [transaction];
      }
    }

    // Sort the groups by month descending (most recent first)
    var sortedKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
    Map<String, List<Transaction>> sortedGrouped = {
      for (var key in sortedKeys) key: grouped[key]!
    };

    return sortedGrouped;
  }
}
