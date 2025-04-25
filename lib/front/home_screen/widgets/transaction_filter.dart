import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/front/home_screen/cubit/transaction_cubit.dart';

class TransactionFilter {
  static void showFilterOptions(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const TransactionFilterSheet(),
    );
  }

  static Future<void> showDateFilter(BuildContext context) async {
    final transactionCubit = context.read<TransactionCubit>();

    final DateTimeRange? selectedRange = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2000),
      lastDate: DateTime(2101),
      initialDateRange: DateTimeRange(
        start: DateTime.now().subtract(const Duration(days: 7)),
        end: DateTime.now(),
      ),
    );

    if (!context.mounted) return;

    if (selectedRange != null) {
      transactionCubit.filterTransactions(
        startDate: selectedRange.start,
        endDate: selectedRange.end,
      );
    }
  }
}

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  final List<String> categories = [];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            'Filter Transactions',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          _buildFilterButton('Food'),
          _buildFilterButton('Travel'),
          _buildFilterButton('Salary'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _applyFilters(context),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(String category) {
    return ElevatedButton(
      onPressed: () => _toggleCategory(category),
      child: Text(categories.contains(category) ? '+ $category' : category),
    );
  }

  void _toggleCategory(String category) {
    setState(() {
      categories.contains(category)
          ? categories.remove(category)
          : categories.add(category);
    });
  }

  void _applyFilters(BuildContext context) {
    final cubit = context.read<TransactionCubit>();
    cubit.loadTransactions();
    if (categories.isNotEmpty) {
      cubit.filterTransactions(categories: categories);
    }
    Navigator.pop(context);
  }
}
