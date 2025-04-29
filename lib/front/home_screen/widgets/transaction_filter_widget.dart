import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';

class TransactionFilterSheet extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final cubit = context.watch<AccountTransactionCubit>();
    final selectedCategories = cubit.state.filters.selectedCategories;
    final categories =
        context.read<CategoryRepository>().getEnabledCategories();

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
          _buildCategoryFilter(context, categories, selectedCategories),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => _applyFilters(context, selectedCategories),
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

  Widget _buildCategoryFilter(
    BuildContext context,
    List<Category> categories,
    List<Category> selectedCategories,
  ) {
    if (categories.isEmpty) {
      return const Text('No categories available');
    }

    return Wrap(
      spacing: 8.0,
      runSpacing: 8.0,
      children: categories.map((category) {
        final isSelected = selectedCategories.contains(category);

        return ElevatedButton(
          onPressed: () => _toggleCategory(context, category, isSelected),
          style: ElevatedButton.styleFrom(
            backgroundColor: isSelected ? Colors.blue : Colors.grey[300],
            foregroundColor: isSelected ? Colors.white : Colors.black,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                category.icon,
                size: 16,
                color: category.color,
              ),
              const SizedBox(width: 8),
              Text(category.title),
            ],
          ),
        );
      }).toList(),
    );
  }

  void _toggleCategory(
      BuildContext context, Category category, bool isSelected) {
    final cubit = context.read<AccountTransactionCubit>();
    final updatedCategories =
        List<Category>.from(cubit.state.filters.selectedCategories);

    if (isSelected) {
      updatedCategories.remove(category);
    } else {
      updatedCategories.add(category);
    }

    cubit.changeSelectedCategories(updatedCategories);
  }

  void _applyFilters(BuildContext context, List<Category> selectedCategories) {
    final cubit = context.read<AccountTransactionCubit>();

    // // Apply category filters
    if (selectedCategories.isNotEmpty) {
      final categoryIds =
          selectedCategories.map((category) => category.id).toList();
      // cubit.filterTransactions(categoryIds: categoryIds);
      cubit.changeSelectedCategories(selectedCategories);
    }
    // cubit.fil(
    //   selectedCategories: selectedCategories,
    // );

    Navigator.pop(context);
  }

  void _resetFilters(BuildContext context) {
    final cubit = context.read<AccountTransactionCubit>();

    // Reset filters in the cubit
    cubit.resetFilters();

    Navigator.pop(context);
  }
}
