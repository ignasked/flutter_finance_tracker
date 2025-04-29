import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/backend/utils/AppColors.dart';
import 'package:money_owl/front/transaction_item.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final bool groupByMonth; // Add a flag to control grouping

  const TransactionList({
    Key? key,
    required this.transactions,
    this.groupByMonth = false, // Default to no grouping
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (groupByMonth) {
      // Group transactions by month
      Map<String, List<Transaction>> groupedTransactions =
          _groupTransactionsByMonth(transactions);

      return ListView(
        children: groupedTransactions.entries.map((entry) {
          final entriesDate = entry.key;
          final monthTransactions = entry.value;

          return ExpansionTile(
            title: Text(entriesDate),
            children: monthTransactions.map((item) {
              return buildTransactionItem(context, item);
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
    return Dismissible(
      key: UniqueKey(),
      confirmDismiss: (direction) async {
        final txCubit = context.read<AccountTransactionCubit>();
        final itemIndex = transactions.indexOf(item);

        final result = await showDialog<bool>(
          context: context,
          builder: (BuildContext context) {
            return AlertDialog(
              title: const Text('Confirm'),
              content: const Text('Are you sure you want to delete?'),
              actions: <Widget>[
                TextButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('No'),
                ),
                TextButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('Yes'),
                ),
              ],
            );
          },
        );

        if (!context.mounted) return false;

        if (result == true) {
          txCubit.deleteTransaction(item);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('${item.title} deleted.')),
          );
        }
        return false;
      },
      background: Container(
        color: Colors.red,
        padding: const EdgeInsets.only(right: 20),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete,
          color: Colors.white,
        ),
      ),
      child: Card(
        child: ListTile(
          leading: Icon(
            item.category.target?.icon,
            color: item.category.target?.color ?? Colors.black,
          ),
          title: Text(item.title),
          subtitle: Text(
            '${item.category.target?.title} | ${item.date.toString().split(' ')[0]}',
          ),
          trailing: Text(
            '${item.isIncome ? '+' : '-'} \$${item.amount.toStringAsFixed(2)}',
            style: TextStyle(
              color: item.isIncome ? Colors.green : Colors.red,
              fontWeight: FontWeight.bold,
            ),
          ),
          onTap: () async {
            final txCubit = context.read<AccountTransactionCubit>();
            final itemIndex = transactions.indexOf(item);

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

    for (var transaction in transactions) {
      final monthYear =
          '${transaction.date.year}-${transaction.date.month.toString().padLeft(2, '0')}';
      if (grouped.containsKey(monthYear)) {
        grouped[monthYear]!.add(transaction);
      } else {
        grouped[monthYear] = [transaction];
      }
    }

    return grouped;
  }
}
