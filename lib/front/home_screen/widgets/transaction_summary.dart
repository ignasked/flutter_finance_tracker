import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_summary_cubit.dart';
import 'package:pvp_projektas/front/home_screen/widgets/transaction_summary_display.dart';

class TransactionSummary extends StatelessWidget {
  final VoidCallback onCalendarPressed;
  final VoidCallback onFilterPressed;

  const TransactionSummary({
    Key? key,
    required this.onCalendarPressed,
    required this.onFilterPressed,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<TransactionCubit, TransactionState>(
          listener: (context, state) {
            print(
                'TransactionState changed: ${state.transactions.length} transactions');
            context
                .read<TransactionSummaryCubit>()
                .calculateSummary(state.transactions);
          },
        ),
      ],
      child: BlocBuilder<TransactionCubit, TransactionState>(
        builder: (context, state) {
          // Calculate summary on initial build and updates
          context
              .read<TransactionSummaryCubit>()
              .calculateSummary(state.transactions);

          return Container(
            decoration: BoxDecoration(
              color: Colors.grey[200],
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(40),
                  blurRadius: 3,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  icon: const Icon(Icons.today, color: Colors.blue),
                  onPressed: onCalendarPressed,
                ),
                const Expanded(
                  child: TransactionSummaryDisplay(),
                ),
                IconButton(
                  icon: const Icon(Icons.filter_list, color: Colors.blue),
                  onPressed: onFilterPressed,
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
