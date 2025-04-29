import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/home_screen/widgets/date_bar_widget.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_list.dart';
import 'package:money_owl/front/home_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/receipt_scan_screen/receipt_analyzer_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(18.0),
          child: BlocBuilder<AccountTransactionCubit, AccountTransactionState>(
            builder: (context, state) {
              if (state.displayedTransactions.isEmpty) {
                return const Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Transaction Summary
                    SummaryBarWidget(),
                    SizedBox(height: 10),

                    // Date Selector
                    DateBarWidget(),
                    SizedBox(height: 6),

                    // No Transactions Message
                    Expanded(
                      child: Center(child: Text('No transactions.')),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Transaction Summary
                  const SummaryBarWidget(),
                  const SizedBox(height: 10),
                  // Date Selector
                  const DateBarWidget(),
                  const SizedBox(height: 6),

                  // Transaction List
                  Expanded(
                    child: TransactionList(
                        transactions: state.displayedTransactions),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showBottomSheet(context);
        },
        child: const Icon(Icons.add),
      ),
    );
  }

  /// Show the bottom sheet for adding transactions or scanning receipts
  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) {
        return Padding(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add),
                title: const Text('Add Transaction'),
                onTap: () async {
                  final accountTransactionCubit =
                      context.read<AccountTransactionCubit>();

                  final TransactionResult? transactionFormResult =
                      await Navigator.push<TransactionResult>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionFromScreen(),
                    ),
                  );

                  if (!context.mounted) return;

                  if (transactionFormResult != null) {
                    accountTransactionCubit
                        .addTransaction(transactionFormResult.transaction);
                  }

                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.receipt),
                title: const Text('Read Receipt'),
                onTap: () {
                  Navigator.pop(context);
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                    ),
                    builder: (context) {
                      return Wrap(
                        children: [
                          const ReceiptAnalyzerWidget(),
                        ],
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
