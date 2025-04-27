import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';

class TransactionSummaryDisplay extends StatelessWidget {
  const TransactionSummaryDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountTransactionCubit, AccountTransactionState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Balance: \$${state.txSummary.balance.toStringAsFixed(2)}',
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${state.txSummary.totalIncome.toStringAsFixed(2)}\$',
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Text(
                  '${state.txSummary.totalExpenses.toStringAsFixed(2)}\$',
                  style: const TextStyle(fontSize: 14, color: Colors.red),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
