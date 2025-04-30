import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/settings_screen/widgets/category_form_widget.dart';
import 'package:money_owl/main.dart';

class CategoryCubit extends Cubit<List<Category>> {
  final CategoryRepository _categoryRepository;
  final AccountTransactionCubit _accountTransactionCubit;

  CategoryCubit(this._categoryRepository, this._accountTransactionCubit)
      : super([]) {
    loadCategories();
  }

  void loadCategories() {
    final categories = _categoryRepository.getAll();
    emit(categories);
  }

  void toggleCategory(Category category, bool isEnabled) {
    final updatedCategory = category.copyWith(isEnabled: isEnabled);
    _categoryRepository.put(updatedCategory);
    final updatedCategories =
        state.map((c) => c.id == category.id ? updatedCategory : c).toList();
    emit(updatedCategories);
  }

  void addCategory(Category category) {
    _categoryRepository.putById(category.id, category);
    emit([...state, category]);
  }

  void editCategory(Category category) {
    _categoryRepository.put(category);

    final index = state.indexWhere((c) => c.id == category.id);
    if (index != -1) {
      state[index] = category; // Directly update the category in the state list
    }

    _accountTransactionCubit.loadAllTransactions(); // force reload
    Defaults().defaultCategory = category;

    emit([...state]);
  }

  void deleteCategory(Category category) {
    _categoryRepository.remove(category.id);
    emit(state.where((c) => c.id != category.id).toList());
  }

  bool isTransactionRemovable(Category category) {
    // Check if the category has related transactions
    return _accountTransactionCubit.txRepo
            .hasTransactionsForCategory(category.id) ||
        category.id == 13;
  }
}

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => CategoryCubit(context.read<CategoryRepository>(),
          context.read<AccountTransactionCubit>()),
      child: BlocBuilder<CategoryCubit, List<Category>>(
        builder: (context, categories) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manage Categories'),
            ),
            body: ListView.builder(
              itemCount: categories.length,
              itemBuilder: (context, index) {
                final category = categories[index];
                final hasTransactions = context
                    .read<CategoryCubit>()
                    .isTransactionRemovable(category);

                return ListTile(
                  leading: Icon(category.icon, color: category.color),
                  title: Text(category.title),
                  subtitle: Text(category.descriptionForAI),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // Edit button
                      IconButton(
                        icon: const Icon(Icons.edit),
                        onPressed: () async {
                          final updatedCategory = await showDialog<Category?>(
                            context: context,
                            builder: (context) =>
                                CategoryFormWidget(initialCategory: category),
                          );

                          if (updatedCategory != null) {
                            context
                                .read<CategoryCubit>()
                                .editCategory(updatedCategory);
                          }
                        },
                      ),
                      // Delete button
                      IconButton(
                        icon: const Icon(Icons.delete),
                        onPressed: hasTransactions
                            ? null // Disable the button if the category has transactions
                            : () async {
                                final confirm = await showDialog<bool>(
                                  context: context,
                                  builder: (context) => AlertDialog(
                                    title: const Text('Delete Category'),
                                    content: Text(
                                        'Are you sure you want to delete the category "${category.title}"?'),
                                    actions: [
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, false),
                                        child: const Text('Cancel'),
                                      ),
                                      TextButton(
                                        onPressed: () =>
                                            Navigator.pop(context, true),
                                        child: const Text('Delete'),
                                      ),
                                    ],
                                  ),
                                );

                                if (confirm == true) {
                                  context
                                      .read<CategoryCubit>()
                                      .deleteCategory(category);
                                }
                              },
                      ),
                      Switch(
                        value: category.isEnabled,
                        onChanged: (value) => context
                            .read<CategoryCubit>()
                            .toggleCategory(category, value),
                      ),
                    ],
                  ),
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                final newCategory = await showDialog<Category?>(
                  context: context,
                  builder: (context) => const CategoryFormWidget(),
                );

                if (newCategory != null) {
                  context.read<CategoryCubit>().addCategory(newCategory);
                }
              },
              tooltip: 'Add Category',
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}
