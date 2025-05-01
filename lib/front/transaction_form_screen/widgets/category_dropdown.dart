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
  // Flags to prevent update cycles
  bool _handlingTypeChange = false;
  bool _handlingCategoryChange = false;
  List<Category> _allCategories = [];

  @override
  void initState() {
    super.initState();
    // Ensure proper category type matching after first build
    WidgetsBinding.instance
        .addPostFrameCallback((_) => _syncCategoryWithTransactionType());
  }

  void _syncCategoryWithTransactionType() {
    if (!mounted) return;

    // Safely get form cubit if available
    final formCubit = context.read<TransactionFormCubit>();
    if (formCubit.state == null) return; // Guard against null state

    final state = formCubit.state;
    final defaultCategory = Defaults().defaultCategory;

    // Safely get categories
    try {
      _allCategories =
          context.read<TransactionsCubit>().getEnabledCategoriesCache();
    } catch (e) {
      // Handle case when TransactionsCubit is not available
      _allCategories = [];
      print('Warning: Could not get categories: $e');
      return;
    }

    // Only change category if it doesn't match current transaction type
    if (state.category != null &&
        state.category?.type != state.selectedType &&
        state.category?.id != defaultCategory.id) {
      final matchingCategories =
          _allCategories.where((c) => c.type == state.selectedType).toList();

      if (matchingCategories.isNotEmpty) {
        _handlingTypeChange = true;
        formCubit.categoryChanged(matchingCategories.first);
        Future.delayed(const Duration(milliseconds: 50), () {
          if (mounted) _handlingTypeChange = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final defaultCategory = Defaults().defaultCategory;

    // Try to get categories safely
    try {
      _allCategories =
          context.read<TransactionsCubit>().getEnabledCategoriesCache();
    } catch (e) {
      // Fallback if TransactionsCubit is not available
      return const Text('Cannot access categories at this time.',
          style: AppStyle.bodyText);
    }

    // Empty state handling
    if (_allCategories.isEmpty) {
      return const Text('No categories available. Please add a category first.',
          style: AppStyle.bodyText);
    }

    // Pre-filter categories by type
    final incomeCategories = _allCategories
        .where((c) =>
            c.type == TransactionType.income && c.id != defaultCategory.id)
        .toList();

    final expenseCategories = _allCategories
        .where((c) =>
            c.type == TransactionType.expense && c.id != defaultCategory.id)
        .toList();

    return BlocConsumer<TransactionFormCubit, TransactionFormState>(
      listenWhen: (previous, current) =>
          previous.selectedType != current.selectedType &&
          !_handlingCategoryChange,
      listener: (context, state) {
        if (_handlingCategoryChange) return;

        _handlingTypeChange = true;

        final matchingCategories = state.selectedType == TransactionType.income
            ? incomeCategories
            : expenseCategories;

        if (state.category != null &&
            state.category?.type != state.selectedType &&
            state.category?.id != defaultCategory.id &&
            matchingCategories.isNotEmpty) {
          Future.microtask(() {
            if (mounted) {
              context
                  .read<TransactionFormCubit>()
                  .categoryChanged(matchingCategories.first);

              Future.delayed(const Duration(milliseconds: 50), () {
                if (mounted) _handlingTypeChange = false;
              });
            }
          });
        } else {
          _handlingTypeChange = false;
        }
      },
      buildWhen: (previous, current) =>
          previous.category != current.category ||
          previous.selectedType != current.selectedType,
      builder: (context, state) {
        // Get filtered categories based on transaction type
        List<Category> filteredCategories = [];

        if (state.selectedType == TransactionType.income) {
          filteredCategories = [...incomeCategories];
        } else {
          filteredCategories = [...expenseCategories];
        }

        // Ensure default category is available
        if (!filteredCategories.any((c) => c.id == defaultCategory.id)) {
          filteredCategories.add(defaultCategory);
        }

        // Get selected category safely
        final selectedCategory = state.category;

        // Ensure the selected category is in the list if not null
        if (selectedCategory != null &&
            !filteredCategories.any((c) => c.id == selectedCategory.id)) {
          filteredCategories.insert(0, selectedCategory);
        }

        // Select the best category to show (safely handle null cases)
        Category validCategory;
        if (selectedCategory != null &&
            filteredCategories.any((c) => c.id == selectedCategory.id)) {
          validCategory = selectedCategory;
        } else {
          validCategory = filteredCategories.isNotEmpty
              ? filteredCategories.firstWhere((c) => c.id != defaultCategory.id,
                  orElse: () => filteredCategories.isNotEmpty
                      ? filteredCategories.first
                      : defaultCategory)
              : defaultCategory;
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
                  Icon(category.icon, color: category.color, size: 20),
                  const SizedBox(width: AppStyle.paddingSmall),
                  Expanded(
                    child: Text(
                      category.title,
                      style: AppStyle.bodyText,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  if (category.id == defaultCategory.id)
                    const Text('Default', style: AppStyle.captionStyle)
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

              _handlingCategoryChange = true;

              formCubit.categoryChanged(value);

              // Update transaction type if needed
              if (value.id != defaultCategory.id &&
                  formCubit.state.selectedType != value.type) {
                Future.microtask(() {
                  if (mounted) formCubit.typeChanged(value.type);
                });
              }

              Future.delayed(const Duration(milliseconds: 100), () {
                if (mounted) _handlingCategoryChange = false;
              });
            }
          },
          decoration: AppStyle.getInputDecoration(labelText: 'Category'),
          isExpanded: true,
          selectedItemBuilder: (context) {
            return filteredCategories.map<Widget>((category) {
              return Row(
                children: [
                  Icon(category.icon, color: category.color, size: 20),
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
