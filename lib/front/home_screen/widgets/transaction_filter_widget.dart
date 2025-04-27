import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';

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

  // static void showAccountFilter(BuildContext context) {
  //   // TODO: Implement account filter dialog
  //   showDialog(
  //     context: context,
  //     builder: (BuildContext context) {
  //       return AlertDialog(
  //         title: const Text('Select Account'),
  //         content: const Text('Account selection dialog to be implemented'),
  //         actions: [
  //           TextButton(
  //             onPressed: () => Navigator.pop(context),
  //             child: const Text('Close'),
  //           ),
  //         ],
  //       );
  //     },
  //   );
  // }

  // static Future<void> showDateFilter(BuildContext context) async {
  //   final transactionCubit = context.read<AccountTransactionCubit>();

  //   final DateTimeRange? selectedRange = await showDateRangePicker(
  //     context: context,
  //     firstDate: DateTime(2000),
  //     lastDate: DateTime(2101),
  //     initialDateRange: DateTimeRange(
  //       start: DateTime.now().subtract(const Duration(days: 7)),
  //       end: DateTime.now(),
  //     ),
  //   );

  //   if (!context.mounted) return;

  //   if (selectedRange != null) {
  //     transactionCubit.filterTransactions(
  //       startDate: selectedRange.start,
  //       endDate: selectedRange.end,
  //     );
  //   }
  // }
}

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({super.key});

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  final List<Category> selectedCategories = [];
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    // Fetch enabled categories from the repository
    _categories = context.read<CategoryRepository>().getEnabledCategories();
  }

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
          FutureBuilder<List<Category>>(
            future: Future.value(_categories),
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const CircularProgressIndicator();
              }

              if (snapshot.hasError) {
                return const Text('Error loading categories');
              }

              final categories = snapshot.data ?? [];

              if (categories.isEmpty) {
                return const Text('No categories available');
              }

              return Wrap(
                spacing: 8.0,
                runSpacing: 8.0,
                children: categories.map((category) {
                  return _buildFilterButton(category);
                }).toList(),
              );
            },
          ),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _applyFilters(context),
            child: const Text('Apply Filters'),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterButton(Category category) {
    final isSelected = selectedCategories.contains(category);

    return ElevatedButton(
      onPressed: () => _toggleCategory(category),
      style: ElevatedButton.styleFrom(
        backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
        foregroundColor: isSelected ? Colors.white : Colors.black,
      ),
      child: Text(category.title),
    );
  }

  void _toggleCategory(Category category) {
    setState(() {
      if (selectedCategories.contains(category)) {
        selectedCategories.remove(category);
      } else {
        selectedCategories.add(category);
      }
    });
  }

  void _applyFilters(BuildContext context) {
    final cubit = context.read<AccountTransactionCubit>();
    cubit.displayTransactionsForSelectedAccount();

    if (selectedCategories.isNotEmpty) {
      // Pass category IDs to the filter
      final categoryIds =
          selectedCategories.map((category) => category.id).toList();
      cubit.filterTransactions(categoryIds: categoryIds);
    }

    Navigator.pop(context);
  }
}
