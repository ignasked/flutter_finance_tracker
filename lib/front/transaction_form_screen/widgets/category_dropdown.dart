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

  // In CategoryDropdown:
  @override
  Widget build(BuildContext context) {
    // ... (rest of the code)
    List<Category> categories =
        context.read<TransactionsCubit>().state.allCategories;
    return BlocSelector<TransactionFormCubit, TransactionFormState, Category?>(
      selector: (state) => state.category,
      builder: (context, selectedCategory) {
        final validCategory = selectedCategory ??
            (categories.isNotEmpty
                ? categories[0]
                : Defaults().defaultCategory);

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
          decoration: AppStyle.getInputDecoration(
            labelText: 'Category',
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
