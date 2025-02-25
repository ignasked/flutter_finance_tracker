import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';
import 'package:pvp_projektas/front/add_transaction_screen/add_transaction_screen.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionList({
    Key? key,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final item = transactions[index];

        return Dismissible(
          key: UniqueKey(),
          confirmDismiss: (direction) async {
            bool result;
            {
              result
              = await showDialog(
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
              if(result) {
                context.read<TransactionCubit>().deleteTransaction(index);
                ScaffoldMessenger.of(context)
                    .showSnackBar(SnackBar(content: Text('$item deleted.')));
              }
            }
            
            return null;
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
                color: item.isIncome ? Colors.green : Colors.red,
              ),
              title: Text(item.title),
              subtitle: Text(
                '${item.category} | ${item.date.toString().split(' ')[0]}',
              ),
              trailing: Text(
                '${item.isIncome ? '+' : '-'} \$${item.amount.toStringAsFixed(
                    2)}',
                style: TextStyle(
                  color: item.isIncome ? Colors.green : Colors.red,
                  fontWeight: FontWeight.bold,
                ),
              ),
              onTap: () async {
                final TransactionResult? transactionFormResult =
                await Navigator.push<TransactionResult?>(
                  context,
                  MaterialPageRoute(
                    builder: (context) =>
                        AddTransactionScreen(
                          transaction: item,
                          index: index,
                        ),
                  ),
                );

                if (transactionFormResult != null) {
                  context
                      .read<TransactionCubit>()
                      .handleTransactionFormResult(transactionFormResult);
                }
              },
            ),
          ),
        );
      },
    );
  }
}
