import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';

class CategoryDropdown extends StatefulWidget {
  const CategoryDropdown({Key? key}) : super(key: key);

  @override
  State<CategoryDropdown> createState() => _CategoryDropdownState();
}

class _CategoryDropdownState extends State<CategoryDropdown> {
  // Track if we're currently handling a transaction type change to prevent cycles
  bool _handlingTypeChange = false;
  // Track if we're currently handling a category change to prevent cycles
  bool _handlingCategoryChange = false;

  @override
  void initState() {
    super.initState();
    // Initial setup to ensure proper category type matching on first build
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _syncCategoryWithTransactionType();
    });
  }

  // Helper method to sync category with transaction type
  void _syncCategoryWithTransactionType() {
    if (!mounted) return;

    final formCubit = context.read<TransactionFormCubit>();
    final state = formCubit.state;
    final defaultCategory = Defaults().defaultCategory;
    final List<Category> allCategories =
        context.read<TransactionsCubit>().getEnabledCategories();

    // If category doesn't match transaction type, find a better match
    if (state.category != null &&
        state.category?.type != state.selectedType &&
        state.category?.id != defaultCategory.id) {
      // Find categories of the current transaction type
      final matchingCategories =
          allCategories.where((c) => c.type == state.selectedType).toList();

      // If we have matching categories, select the first one
      if (matchingCategories.isNotEmpty) {
        _handlingTypeChange = true;
        formCubit.categoryChanged(matchingCategories.first);
        Future.delayed(const Duration(milliseconds: 50), () {
          _handlingTypeChange = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Get categories - either predefined or from the state
    final defaultCategory = Defaults().defaultCategory.copyWith();
    final List<Category> allCategories =
        context.read<TransactionsCubit>().getEnabledCategories();

    // Split categories by type for easier lookup
    final List<Category> incomeCategories = allCategories
        .where((c) =>
            c.type == TransactionType.income && c.id != defaultCategory.id)
        .toList();

    final List<Category> expenseCategories = allCategories
        .where((c) =>
            c.type == TransactionType.expense && c.id != defaultCategory.id)
        .toList();

    if (allCategories.isEmpty) {
      return const Text('No categories available. Please add a category first.',
          style: AppStyle.bodyText);
    }

    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (previous, current) =>
          previous.selectedType != current.selectedType &&
          !_handlingCategoryChange,
      listener: (context, state) {
        // Only respond to transaction type changes if we're not already handling a category change
        if (_handlingCategoryChange) return;

        // Set flag to prevent cycles
        _handlingTypeChange = true;

        // Find matching categories for the selected transaction type
        List<Category> matchingCategories =
            state.selectedType == TransactionType.income
                ? incomeCategories
                : expenseCategories;

        // If current category doesn't match new transaction type, switch to appropriate one
        if (state.category != null &&
            state.category?.type != state.selectedType &&
            state.category?.id != defaultCategory.id &&
            matchingCategories.isNotEmpty) {
          Future.microtask(() {
            if (mounted) {
              // Always use the first category of the matching type
              context
                  .read<TransactionFormCubit>()
                  .categoryChanged(matchingCategories.first);
              // Reset flag after the operation is complete
              Future.delayed(const Duration(milliseconds: 50), () {
                _handlingTypeChange = false;
              });
            }
          });
        } else {
          // Reset flag if no category change was needed
          _handlingTypeChange = false;
        }
      },
      buildWhen: (previous, current) =>
          previous.category != current.category ||
          previous.selectedType != current.selectedType,
      builder: (context, state) {
        // Get categories matching the selected transaction type
        List<Category> filteredCategories = [];

        if (state.selectedType == TransactionType.income) {
          // For income, show income categories first
          filteredCategories = [...incomeCategories];
          // Add default category if it's not already in the list
          if (!filteredCategories.any((c) => c.id == defaultCategory.id)) {
            filteredCategories.add(defaultCategory);
          }
        } else {
          // For expense, show expense categories first
          filteredCategories = [...expenseCategories];
          // Add default category if it's not already in the list
          if (!filteredCategories.any((c) => c.id == defaultCategory.id)) {
            filteredCategories.add(defaultCategory);
          }
        }

        // Make sure we have at least one category
        if (filteredCategories.isEmpty) {
          filteredCategories = [defaultCategory];
        }

        // Add the currently selected category if it's not in the filtered list
        final selectedCategory = state.category;
        if (selectedCategory != null &&
            !filteredCategories.any((c) => c.id == selectedCategory.id)) {
          filteredCategories.insert(0, selectedCategory);
        }

        // Choose the most appropriate category for the dropdown
        Category validCategory;
        if (selectedCategory != null &&
            filteredCategories.any((c) => c.id == selectedCategory.id)) {
          // Use the currently selected category if it's in the filtered list
          validCategory = selectedCategory;
        } else if (filteredCategories.length > 1) {
          // Use the first non-default category if available
          validCategory = filteredCategories.firstWhere(
              (c) => c.id != defaultCategory.id,
              orElse: () => filteredCategories.first);
        } else {
          // Fall back to the first category in the filtered list
          validCategory = filteredCategories.first;
        }

        return DropdownButtonFormField<Category>(
          key: ValueKey(
              'category_dropdown_${validCategory.id}_${state.selectedType.index}'),
          value: validCategory,
          items: filteredCategories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Row(
                children: [
                  Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                  const SizedBox(width: AppStyle.paddingSmall),
                  Expanded(
                    child: Text(
                      category.title,
                      style: AppStyle.bodyText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (category.id == defaultCategory.id)
                    Text(
                      'Default',
                      style: AppStyle.captionStyle,
                    )
                  else
                    Text(
                      category.type == TransactionType.income
                          ? 'Income'
                          : 'Expense',
                      style: AppStyle.captionStyle.copyWith(
                        color: category.type == TransactionType.income
                            ? AppStyle.incomeColor
                            : AppStyle.expenseColor,
                      ),
                    ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) {
            if (value != null && !_handlingTypeChange) {
              final formCubit = context.read<TransactionFormCubit>();

              // Set flag to prevent cycles
              _handlingCategoryChange = true;

              // Get current transaction type
              final currentType = formCubit.state.selectedType;

              // Update the selected category first
              formCubit.categoryChanged(value);

              // Then ensure transaction type matches the category type (for non-default categories)
              if (value.id != defaultCategory.id && currentType != value.type) {
                // Force UI update by using microtask to ensure it happens after this method completes
                Future.microtask(() {
                  if (mounted) {
                    formCubit.typeChanged(value.type);
                  }
                });
              }

              // Reset flag after a short delay to allow state to settle
              Future.delayed(const Duration(milliseconds: 150), () {
                if (mounted) {
                  _handlingCategoryChange = false;
                }
              });
            }
          },
          decoration: AppStyle.getInputDecoration(
            labelText: 'Category',
          ),
          isExpanded: true,
          selectedItemBuilder: (BuildContext context) {
            return filteredCategories.map<Widget>((Category category) {
              return Row(
                children: <Widget>[
                  Icon(
                    category.icon,
                    color: category.color,
                    size: 20,
                  ),
                  const SizedBox(width: AppStyle.paddingSmall),
                  Expanded(
                    child: Text(
                      category.title,
                      style: AppStyle.bodyText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              );
            }).toList();
          },
        );
      },
    );
  }
}
