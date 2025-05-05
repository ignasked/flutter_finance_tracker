import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/settings_screen/widgets/category_form_widget.dart';

class CategoryManagementScreen extends StatelessWidget {
  const CategoryManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DataManagementCubit, DataManagementState>(
      builder: (context, dataState) {
        final categories = dataState.allCategories;
        final dataManagementCubit = context.read<DataManagementCubit>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Categories'),
            bottom: dataState.status == LoadingStatus.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4.0),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: ListView.builder(
            itemCount: categories.length,
            itemBuilder: (context, index) {
              final category = categories[index];
              final bool isDefaultCategory =
                  category.id >= 1 && category.id <= 19;
              final bool hasTransactions =
                  dataManagementCubit.hasTransactionsForCategory(category.id);
              final bool canDelete = !isDefaultCategory && !hasTransactions;

              return ListTile(
                leading: Icon(category.icon, color: category.color),
                title: Text(category.title),
                subtitle: Text(category.descriptionForAI ?? ''),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Category',
                      onPressed: () async {
                        final updatedCategory = await showDialog<Category?>(
                          context: context,
                          builder: (_) =>
                              CategoryFormWidget(initialCategory: category),
                        );

                        if (updatedCategory != null) {
                          dataManagementCubit.updateCategory(updatedCategory);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: canDelete
                          ? 'Delete Category'
                          : (isDefaultCategory
                              ? 'Cannot delete default category'
                              : 'Cannot delete category with transactions'),
                      color: canDelete ? null : Theme.of(context).disabledColor,
                      onPressed: canDelete
                          ? () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Category'),
                                  content: Text(
                                      'Are you sure you want to delete the category "${category.title}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.red),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                dataManagementCubit.deleteCategory(category.id);
                              }
                            }
                          : null,
                    ),
                    Switch(
                      value: category.isEnabled,
                      onChanged: (value) {
                        final toggledCategory =
                            category.copyWith(isEnabled: value);
                        dataManagementCubit.updateCategory(toggledCategory);
                      },
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
                builder: (_) => BlocProvider.value(
                  value: dataManagementCubit,
                  child: const CategoryFormWidget(),
                ),
              );

              if (newCategory != null) {
                dataManagementCubit.addCategory(newCategory);
              }
            },
            tooltip: 'Add Category',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
