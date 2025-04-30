import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';

class TransactionSummaryDisplay extends StatelessWidget {
  const TransactionSummaryDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionsCubit, TransactionsState>(
      builder: (context, state) {
        FilterState filterState = context.read<FilterCubit>().state;

        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              '${state.summary.balanceString} ${filterState.selectedAccount?.currencySymbolOrCurrency ?? Defaults().defaultCurrencySymbol}',
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '${state.summary.totalIncomeString} ${filterState.selectedAccount?.currencySymbolOrCurrency ?? Defaults().defaultCurrencySymbol}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  '${state.summary.totalExpensesString} ${filterState.selectedAccount?.currencySymbolOrCurrency ?? Defaults().defaultCurrencySymbol}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.red,
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
  }
}
