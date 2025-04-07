import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';

import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/front/add_transaction_screen/add_transaction_screen.dart';

import 'package:pvp_projektas/front/home_screen/widgets/transaction_list.dart';
import 'package:pvp_projektas/front/home_screen/widgets/transaction_summary.dart';
import 'package:pvp_projektas/front/home_screen/widgets/transaction_filter.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, state) {
              if (state.transactions.isEmpty) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 1,
                      child: TransactionSummary(
                        onCalendarPressed: () =>
                            TransactionFilter.showDateFilter(context),
                        onFilterPressed: () =>
                            TransactionFilter.showFilterOptions(context),
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Expanded(
                      flex: 6,
                      child: Center(child: Text('No transactions.')),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: TransactionSummary(
                      onCalendarPressed: () =>
                          TransactionFilter.showDateFilter(context),
                      onFilterPressed: () =>
                          TransactionFilter.showFilterOptions(context),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Expanded(
                    flex: 6,
                    child: TransactionList(transactions: state.transactions),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final transactionCubit = context.read<TransactionCubit>();

          final TransactionResult? transactionFormResult =
              await Navigator.push<TransactionResult>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );

          if (!context.mounted) return;

          if (transactionFormResult != null) {
            transactionCubit.handleTransactionFormResult(transactionFormResult);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
