import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';

class TransactionSummaryDisplay extends StatelessWidget {
  const TransactionSummaryDisplay({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountTransactionCubit, AccountTransactionState>(
      builder: (context, state) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              context
                          .read<AccountTransactionCubit>()
                          .state
                          .filters
                          .selectedAccount !=
                      null
                  ? '${state.txSummary.balanceString} ${context.read<AccountTransactionCubit>().state.filters.selectedAccount!.currencySymbolOrCurrency}'
                  : '${state.txSummary.balanceString} ${Defaults().defaultCurrencySymbol}',
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
                  context
                              .read<AccountTransactionCubit>()
                              .state
                              .filters
                              .selectedAccount !=
                          null
                      ? '${state.txSummary.totalIncomeString} ${context.read<AccountTransactionCubit>().state.filters.selectedAccount!.currencySymbolOrCurrency}'
                      : '${state.txSummary.totalIncomeString} ${Defaults().defaultCurrencySymbol}',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: Colors.green,
                  ),
                ),
                const SizedBox(width: 16),
                Text(
                  context
                              .read<AccountTransactionCubit>()
                              .state
                              .filters
                              .selectedAccount !=
                          null
                      ? '${state.txSummary.totalExpensesString} ${context.read<AccountTransactionCubit>().state.filters.selectedAccount!.currencySymbolOrCurrency}'
                      : '${state.txSummary.totalExpensesString} ${Defaults().defaultCurrencySymbol}',
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
