import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction_result.dart';

import 'package:money_owl/front/home_screen/cubit/transaction_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';

import 'package:money_owl/front/home_screen/widgets/transaction_list.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_summary.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_filter.dart';
import 'package:money_owl/front/settings_screen/widgets/receipt_analyzer_widget.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    bool isReceiptAnalyzerOpen =
        false; // Move this variable outside the StatefulBuilder

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
        onPressed: () {
          showModalBottomSheet(
            context: context,
            isScrollControlled: true, // Allows the bottom sheet to expand fully
            shape: const RoundedRectangleBorder(
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            builder: (context) {
              return StatefulBuilder(
                builder: (BuildContext context, StateSetter setState) {
                  return Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 300),
                      child: isReceiptAnalyzerOpen
                          ? Column(
                              key: const ValueKey('ReceiptAnalyzer'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.arrow_back),
                                      onPressed: () {
                                        setState(() {
                                          isReceiptAnalyzerOpen = false;
                                        });
                                      },
                                    ),
                                    const Text(
                                      'Read Receipt',
                                      style: TextStyle(
                                        fontSize: 18,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 16),
                                const ReceiptAnalyzerWidget(),
                              ],
                            )
                          : Column(
                              key: const ValueKey('MainOptions'),
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                ListTile(
                                  leading: const Icon(Icons.add),
                                  title: const Text('Add Transaction'),
                                  onTap: () async {
                                    Navigator.pop(
                                        context); // Close the bottom sheet
                                    final transactionCubit =
                                        context.read<TransactionCubit>();

                                    final TransactionResult?
                                        transactionFormResult =
                                        await Navigator.push<TransactionResult>(
                                      context,
                                      MaterialPageRoute(
                                        builder: (context) =>
                                            const TransactionFromScreen(),
                                      ),
                                    );

                                    if (!context.mounted) return;

                                    if (transactionFormResult != null) {
                                      transactionCubit
                                          .handleTransactionFormResult(
                                              transactionFormResult);
                                    }
                                  },
                                ),
                                ListTile(
                                  leading: const Icon(Icons.receipt),
                                  title: const Text('Read Receipt'),
                                  onTap: () {
                                    setState(() {
                                      isReceiptAnalyzerOpen = true;
                                    });
                                  },
                                ),
                              ],
                            ),
                    ),
                  );
                },
              );
            },
          );
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
