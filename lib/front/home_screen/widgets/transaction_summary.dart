import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/utils/transaction_utils.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/utils/AppColors.dart';

class TransactionSummary extends StatelessWidget {
  //TODO: remove this and use transaction cubit
  final List<Transaction> transactions;
  final VoidCallback onCalendarPressed;
  final VoidCallback onFilterPressed;

  const TransactionSummary(
      {Key? key, required this.transactions, required this.onCalendarPressed, required this.onFilterPressed})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
        decoration: BoxDecoration(
          color: Colors.grey[200],
          boxShadow: [
            BoxShadow(
                color: Colors.black.withOpacity(0.1),
                blurRadius: 3,
                offset: const Offset(0, 3))
          ],
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            IconButton(
              icon: const Icon(Icons.today, color: Colors.blue),
              onPressed: onCalendarPressed,
            ),
            Expanded(
                child: Text(
              'Balance: \$${calculateBalance(transactions).toStringAsFixed(2)}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              textAlign: TextAlign.center,
            )),
            IconButton(
              icon: const Icon(Icons.filter_list, color: Colors.blue),
              onPressed: onFilterPressed
            ),
          ],
        ));

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Balance: \$${calculateBalance(transactions).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        Text(
          'Income: \$${calculateIncome(transactions).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, color: Colors.green),
        ),
        Text(
          'Expenses: \$${calculateExpenses(transactions).toStringAsFixed(2)}',
          style: const TextStyle(fontSize: 14, color: Colors.red),
        ),
      ],
    );
  }
}
