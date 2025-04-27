import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/front/settings_screen/widgets/add_category_widget.dart';

class CategoryManagementScreen extends StatefulWidget {
  @override
  _CategoryManagementScreenState createState() =>
      _CategoryManagementScreenState();
}

class _CategoryManagementScreenState extends State<CategoryManagementScreen> {
  late final CategoryRepository _categoryRepository;
  List<Category> _categories = [];

  @override
  void initState() {
    super.initState();
    _initializeRepository();
  }

  Future<void> _initializeRepository() async {
    _categoryRepository = context.read<CategoryRepository>();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = _categoryRepository.getAll();
    setState(() {
      _categories = categories;
    });
  }

  void _toggleCategory(Category category, bool isEnabled) {
    final updatedCategory = category.copyWith(isEnabled: isEnabled);
    _categoryRepository.put(updatedCategory); // Save the updated category
    setState(() {
      _categories[_categories.indexWhere((c) => c.id == category.id)] =
          updatedCategory;
    });
  }

  void _addCategory() async {
    final newCategory = await showDialog<Category?>(
      context: context,
      builder: (context) => AddCategoryWidget(),
    );

    if (newCategory != null) {
      _categoryRepository.put(newCategory); // Save the new category
      setState(() {
        _categories.add(newCategory);
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Categories'),
      ),
      body: ListView.builder(
        itemCount: _categories.length,
        itemBuilder: (context, index) {
          final category = _categories[index];
          return ListTile(
            leading: Icon(category.icon, color: category.color),
            title: Text(category.title),
            subtitle: Text(category.descriptionForAI),
            trailing: Switch(
              value: category.isEnabled,
              onChanged: (value) => _toggleCategory(category, value),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addCategory,
        child: const Icon(Icons.add),
        tooltip: 'Add Category',
      ),
    );
  }
}
