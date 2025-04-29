import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:money_owl/backend/utils/enums.dart';

class CategoryDropdown extends StatelessWidget {
  const CategoryDropdown({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Category>>(
      future: Future.value(
          context.read<CategoryRepository>().getEnabledCategories()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return const Text('Error loading categories');
        }

        final categories = snapshot.data ?? [];

        return DropdownButtonFormField<Category>(
          value: context.watch<TransactionFormCubit>().state.category ??
              Defaults().defaultCategory,
          items: categories.map((category) {
            return DropdownMenuItem(
              value: category,
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      Icon(category.icon, color: category.color),
                      const SizedBox(width: 8),
                      Text(category.title), // Category title
                    ],
                  ),
                  Text(
                    category.type == TransactionType.income
                        ? ' Income'
                        : ' Expense', // Transaction type
                    style: TextStyle(
                      fontSize: 14,
                      color: category.type == TransactionType.income
                          ? Colors.green
                          : Colors.red,
                    ),
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: (value) =>
              context.read<TransactionFormCubit>().categoryChanged(value!),
          decoration: const InputDecoration(
            labelText: 'Category',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
