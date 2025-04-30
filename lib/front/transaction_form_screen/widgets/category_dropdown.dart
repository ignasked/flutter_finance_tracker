import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';

class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get categories once during build and cache them
    final categories = context.read<TransactionsCubit>().getEnabledCategories();
    final defaultCategory = Defaults().defaultCategory;

    // Add default category if needed and not already in list
    if (!categories.any((c) => c.id == defaultCategory.id) &&
        defaultCategory.isEnabled) {
      categories.insert(0, defaultCategory);
    }

    // If categories are empty (even after adding default), show a message
    if (categories.isEmpty) {
      return const Text('No categories available. Please add a category first.',
          style: AppStyle.bodyText);
    }

    // Use BlocSelector for more efficient rebuilds - only when category changes
    return BlocSelector<TransactionFormCubit, TransactionFormState, Category?>(
      selector: (state) => state.category,
      builder: (context, selectedCategory) {
        // Ensure the selected category is valid or use default
        final validCategory = selectedCategory ??
            (categories.isNotEmpty ? categories[0] : defaultCategory);

        return DropdownButtonFormField<Category>(
          value: validCategory,
          items: categories.map((category) {
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
                  const SizedBox(width: AppStyle.paddingMedium),
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
            if (value != null) {
              context.read<TransactionFormCubit>().categoryChanged(value);
            }
          },
          decoration: const InputDecoration(
            labelText: 'Category',
            labelStyle: AppStyle.bodyText,
            border: OutlineInputBorder(),
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppStyle.primaryColor, width: 2.0),
            ),
          ),
          isExpanded: true,
          selectedItemBuilder: (BuildContext context) {
            return categories.map<Widget>((Category category) {
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
              );
            }).toList();
          },
        );
      },
    );
  }
}
