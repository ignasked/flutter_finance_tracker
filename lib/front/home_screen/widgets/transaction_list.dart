import 'package:flutter/material.dart';
import 'package:pvp_projektas/models/Transaction.dart';
import 'package:pvp_projektas/screens/add_transaction_screen.dart';

class TransactionList extends StatelessWidget {
  final List<Transaction> transactions;
  final Function(Transaction updatedTransaction, int index) onUpdate;

  const TransactionList({
    Key? key,
    required this.transactions,
    required this.onUpdate,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final transaction = transactions[index];
        return Card(
          child: ListTile(
            leading: Icon(
              transaction.isIncome ? Icons.arrow_upward : Icons.arrow_downward,
              color: transaction.isIncome ? Colors.green : Colors.red,
            ),
            title: Text(transaction.title),
            subtitle: Text(
              '${transaction.category} | ${transaction.date.toString().split(' ')[0]}',
            ),
            trailing: Text(
              '${transaction.isIncome ? '+' : '-'} \$${transaction.amount.toStringAsFixed(2)}',
              style: TextStyle(
                color: transaction.isIncome ? Colors.green : Colors.red,
                fontWeight: FontWeight.bold,
              ),
            ),
            onTap: () async {
              final updatedTransaction = await Navigator.push<Transaction>(
                context,
                MaterialPageRoute(
                  builder: (context) => AddTransactionScreen(
                    transaction: transaction,
                  ),
                ),
              );
              if (updatedTransaction != null) {
                onUpdate(updatedTransaction, index);
              }
            },
          ),
        );
      },
    );
  }
}
