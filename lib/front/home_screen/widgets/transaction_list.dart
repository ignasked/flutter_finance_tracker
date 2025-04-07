import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';
import 'package:pvp_projektas/front/add_transaction_screen/add_transaction_screen.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/utils/AppColors.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionList({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
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
            return Dismissible(
              key: UniqueKey(),
              confirmDismiss: (direction) async {
                final transactionCubit = context.read<TransactionCubit>();
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
                  transactionCubit.deleteTransaction(itemIndex);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$item deleted.')),
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
                    item.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
                    color: item.isIncome
                        ? ColorPalette.income
                        : ColorPalette.expense,
                  ),
                  title: Text(item.title),
                  subtitle: Text(
                    '${item.category} | ${item.date.toString().split(' ')[0]}',
                  ),
                  trailing: Text(
                    '${item.isIncome ? '+' : '-'} \$${item.amount.toStringAsFixed(2)}',
                    style: TextStyle(
                      color: item.isIncome ? Colors.green : Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () async {
                    final transactionCubit = context.read<TransactionCubit>();
                    final itemIndex = transactions.indexOf(item);

                    final TransactionResult? transactionFormResult =
                        await Navigator.push<TransactionResult>(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AddTransactionScreen(
                          transaction: item,
                          index: itemIndex,
                        ),
                      ),
                    );

                    if (!context.mounted) return;

                    if (transactionFormResult != null) {
                      transactionCubit
                          .handleTransactionFormResult(transactionFormResult);
                    }
                  },
                ),
              ),
            );
          }).toList(),
        );
      }).toList(),
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
