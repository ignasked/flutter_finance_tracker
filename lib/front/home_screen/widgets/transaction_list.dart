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
        return Card(
          child: ListTile(
            leading: Icon(
              transactions[index].isIncome
                  ? Icons.arrow_upward
                  : Icons.arrow_downward,
              color: transactions[index].isIncome ? Colors.green : Colors.red,
            ),
            title: Text(transactions[index].title),
            subtitle: Text(
              '${transactions[index].category} | ${transactions[index].date.toString().split(' ')[0]}',
            ),
            trailing: Text(
              '${transactions[index].isIncome ? '+' : '-'} \$${transactions[index].amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: transactions[index].isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              final TransactionResult? transactionFormResult =
                  await Navigator.push<TransactionResult?>(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(
                    transaction: transactions[index],
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
        );
      },
    );
  }
}
