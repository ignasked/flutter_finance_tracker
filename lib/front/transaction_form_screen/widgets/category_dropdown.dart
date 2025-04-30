import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:money_owl/backend/utils/enums.dart';

class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get categories directly
    final categories =
        context.read<CategoryRepository>().getEnabledCategories();
    final defaultCategory = Defaults().defaultCategory;

    // Ensure default category is in the list if it exists and is enabled or if it's the selected one
    final selectedCategory =
        context.watch<TransactionFormCubit>().state.category;
    // Removed redundant null check for defaultCategory
    if (!categories.any((c) => c.id == defaultCategory.id) &&
        (defaultCategory.isEnabled ||
            selectedCategory?.id == defaultCategory.id)) {
      categories.insert(0, defaultCategory); // Add default if not present
    }

    // If categories are empty (even after adding default), show a message
    if (categories.isEmpty) {
      return const Text('No categories available. Please add a category first.',
          style: AppStyle.bodyText);
    }

    return DropdownButtonFormField<Category>(
      value: selectedCategory ?? defaultCategory,
      items: categories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Icon(
                category.icon,
                color: category.color,
                size: 20, // Slightly smaller icon
              ),
              const SizedBox(
                  width: AppStyle.paddingSmall), // Use AppStyle padding
              Expanded(
                // Allow text to wrap or truncate
                child: Text(
                  category.title,
                  style: AppStyle.bodyText, // Use AppStyle
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(
                  width: AppStyle.paddingMedium), // Use AppStyle padding
              Text(
                category.type == TransactionType.income ? 'Income' : 'Expense',
                style: AppStyle.captionStyle.copyWith(
                  // Use AppStyle caption
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
        labelStyle: AppStyle.bodyText, // Use AppStyle
        border: OutlineInputBorder(),
      ),
      isExpanded: true, // Ensure dropdown takes full width
      selectedItemBuilder: (BuildContext context) {
        // Custom builder for selected item
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
                category.type == TransactionType.income ? 'Income' : 'Expense',
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
  }
}
