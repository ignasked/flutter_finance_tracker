import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({super.key});

  /// Static method to show the filter sheet
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const TransactionFilterSheet(),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  final List<Category> selectedCategories = [];
  late List<Category> _categories;

  @override
  void initState() {
    super.initState();
    // Fetch enabled categories from the repository // TODO: get enabled categories from somewhere once
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
          _buildCategoryFilter(context),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _applyFilters(context),
            child: const Text('Apply Filters'),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: () => _resetFilters(context),
            child: const Text(
              'Reset Filters',
              style: TextStyle(color: Colors.red),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryFilter(BuildContext context) {
    if (_categories.isEmpty) {
      return const Text('No categories available');
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: _categories.map((category) {
        return _buildFilterButton(category);
      }).toList(),
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

    // Apply category filters
    if (selectedCategories.isNotEmpty) {
      final categoryIds =
          selectedCategories.map((category) => category.id).toList();
      cubit.filterTransactions(categoryIds: categoryIds);
    }

    Navigator.pop(context);
  }

  void _resetFilters(BuildContext context) {
    final cubit = context.read<AccountTransactionCubit>();

    // Reset filters in the cubit
    cubit.resetFilters();

    // Clear selected categories in the UI
    setState(() {
      selectedCategories.clear();
    });

    Navigator.pop(context);
  }
}
