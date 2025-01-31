import 'package:flutter/material.dart';
import 'package:pvp_projektas/models/Transaction.dart';
import 'package:pvp_projektas/utils/transaction_utils.dart';

class TransactionSummary extends StatelessWidget {
  final List<Transaction> transactions;

  const TransactionSummary({Key? key, required this.transactions})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balance: \$${calculateBalance(transactions).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
        ),
        Text(
          'Income: \$${calculateIncome(transactions).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, color: Colors.green),
        ),
        Text(
          'Expenses: \$${calculateExpenses(transactions).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 16, color: Colors.red),
        ),
      ],
    );
  }
}
