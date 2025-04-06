import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_summary_cubit.dart';

class TransactionSummaryDisplay extends StatelessWidget {
  const TransactionSummaryDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionSummaryCubit, TransactionSummaryState>(
      builder: (context, state) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Balance: \$${state.balance.toStringAsFixed(2)}',
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
                  '${state.income.toStringAsFixed(2)}\$',
                  style: const TextStyle(fontSize: 14, color: Colors.green),
                ),
                const SizedBox(width: 10),
                Text(
                  '${state.expenses.toStringAsFixed(2)}\$',
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
