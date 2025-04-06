import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';

import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/front/add_transaction_screen/add_transaction_screen.dart';

import 'package:pvp_projektas/front/home_screen/widgets/transaction_list.dart';
import 'package:pvp_projektas/front/home_screen/widgets/transaction_summary.dart';

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
                        onCalendarPressed: () => _showDateFilter(context),
                        onFilterPressed: () => _showFilterOptions(context),
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
                      onCalendarPressed: () => _showDateFilter(context),
                      onFilterPressed: () => _showFilterOptions(context),
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
          final TransactionResult? transactionFormResult =
              await Navigator.push<TransactionResult>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );

          if (transactionFormResult != null) {
            context
                .read<TransactionCubit>()
                .handleTransactionFormResult(transactionFormResult);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}

// TODO: move out show filtering options
void _showFilterOptions(BuildContext context) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true, // Allows full-height modal
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
    ),
    builder: (context) {
      List<String> categories = []; // Move inside the builder for persistence
      return StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Filter Transactions',
                    style:
                        TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    setModalState(() {
                      // Updates state inside modal
                      categories.contains('Food')
                          ? categories.remove('Food')
                          : categories.add('Food');
                    });
                  },
                  child: Text(categories.contains('Food') ? '+ Food' : 'Food'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setModalState(() {
                      categories.contains('Travel')
                          ? categories.remove('Travel')
                          : categories.add('Travel');
                    });
                  },
                  child: Text(
                      categories.contains('Travel') ? '+ Travel' : 'Travel'),
                ),
                ElevatedButton(
                  onPressed: () {
                    setModalState(() {
                      categories.contains('Salary')
                          ? categories.remove('Salary')
                          : categories.add('Salary');
                    });
                  },
                  child: Text(
                      categories.contains('Salary') ? '+ Salary' : 'Salary'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: () {
                    context.read<TransactionCubit>().loadTransactions();
                    if (categories.isNotEmpty) {
                      context
                          .read<TransactionCubit>()
                          .filterTransactions(categories: categories);
                    }
                    Navigator.pop(context);
                  },
                  child: const Text('Apply Filters'),
                ),
              ],
            ),
          );
        },
      );
    },
  );
}

void _showDateFilter(BuildContext context) async {
  DateTimeRange? selectedRange = await showDateRangePicker(
    context: context,
    firstDate: DateTime(2000),
    lastDate: DateTime(2101),
    initialDateRange: DateTimeRange(
      start: DateTime.now().subtract(const Duration(days: 7)),
      // Default to last week
      end: DateTime.now(),
    ),
  );

  if (selectedRange != null) {
    context.read<TransactionCubit>().filterTransactions(
          startDate: selectedRange.start,
          endDate: selectedRange.end,
        );
  }
}
