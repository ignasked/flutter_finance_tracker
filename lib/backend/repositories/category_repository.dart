import 'package:money_owl/utils/enums.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/category.dart';
import 'package:flutter/material.dart';

class CategoryRepository {
  static Store? _store; // Singleton Store instance

  /// Private constructor
  CategoryRepository._();

  /// Initializes ObjectBox store and adds default categories if needed
  static Future<CategoryRepository> create() async {
    if (_store == null) {
      final docsDir = await getApplicationDocumentsDirectory();
      _store =
          await openStore(directory: p.join(docsDir.path, "categories_db"));
    }

    final repository = CategoryRepository._();

    // Add default categories if they don't exist
    await repository._initializeDefaultCategories();

    return repository;
  }

  /// Get the ObjectBox store
  Store get store {
    if (_store == null) {
      throw Exception(
          'Store is not initialized. Call CategoryRepository.create() first.');
    }
    return _store!;
  }

  /// Dispose the ObjectBox store
  void dispose() {
    _store?.close();
    _store = null;
  }

  /// Get all categories
  List<Category> getCategories() {
    try {
      return store.box<Category>().getAll();
    } catch (e) {
      print('Error fetching categories: $e');
      return [];
    }
  }

  /// Get a category by ID
  Category? getCategory(int id) {
    try {
      return store.box<Category>().get(id);
    } catch (e) {
      print('Error fetching category with ID $id: $e');
      return null;
    }
  }

  /// Add or update a category
  void addCategory(Category category) {
    try {
      store.box<Category>().put(category);
    } catch (e) {
      print('Error adding/updating category: $e');
    }
  }

  /// Delete a category by ID
  void deleteCategory(int id) {
    try {
      store.box<Category>().remove(id);
    } catch (e) {
      print('Error deleting category with ID $id: $e');
    }
  }

  /// Delete all categories
  void deleteAllCategories() {
    try {
      store.box<Category>().removeAll();
    } catch (e) {
      print('Error deleting all categories: $e');
    }
  }

  /// Add multiple categories
  void addCategories(List<Category> categories) {
    try {
      store.box<Category>().putMany(categories);
    } catch (e) {
      print('Error adding multiple categories: $e');
    }
  }

  /// Check if a category title is unique
  bool isTitleUnique(String title) {
    try {
      final query =
          store.box<Category>().query(Category_.title.equals(title)).build();
      final isUnique = query.find().isEmpty;
      query.close();
      return isUnique;
    } catch (e) {
      print('Error checking if title is unique: $e');
      return false;
    }
  }

  /// Fetch only enabled categories
  List<Category> getEnabledCategories() {
    try {
      final query =
          store.box<Category>().query(Category_.isEnabled.equals(true)).build();
      final enabledCategories = query.find();
      query.close();
      return enabledCategories;
    } catch (e) {
      print('Error fetching enabled categories: $e');
      return [];
    }
  }

  /// Fetch enabled category titles as a comma-separated string
  String getEnabledCategoryTitles() {
    final enabledCategories = getEnabledCategories();
    if (enabledCategories.isEmpty) {
      return 'No enabled categories';
    }
    return enabledCategories.map((category) => category.title).join(', ');
  }

  /// Initialize default categories
  Future<void> _initializeDefaultCategories() async {
    final categoryBox = store.box<Category>();

    // Check if there are any existing categories
    if (categoryBox.isEmpty()) {
      final defaultCategories = [
        Category(
          title: 'Food',
          descriptionForAI: 'Expenses related to food and dining',
          colorValue: Colors.red.value, // Convert Color to int
          iconCodePoint: Icons.fastfood.codePoint, // Convert IconData to int
          typeValue: TransactionType.expense.index, // Convert enum to int
        ),
        Category(
          title: 'Transportation',
          descriptionForAI: 'Expenses related to transportation',
          colorValue: Colors.blue.value,
          iconCodePoint: Icons.directions_car.codePoint,
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Entertainment',
          descriptionForAI: 'Expenses related to entertainment',
          colorValue: Colors.purple.value,
          iconCodePoint: Icons.movie.codePoint,
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Salary',
          descriptionForAI: 'Income from salary',
          colorValue: Colors.green.value,
          iconCodePoint: Icons.attach_money.codePoint,
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Healthcare',
          descriptionForAI: 'Expenses related to healthcare',
          colorValue: Colors.orange.value,
          iconCodePoint: Icons.local_hospital.codePoint,
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Utilities',
          descriptionForAI: 'Expenses related to utilities',
          colorValue: Colors.yellow.value,
          iconCodePoint: Icons.lightbulb.codePoint,
          typeValue: TransactionType.expense.index,
        ),
      ];

      // Add default categories to the database
      try {
        categoryBox.putMany(defaultCategories);
        print('Default categories added.');
      } catch (e) {
        print('Error adding default categories: $e');
      }
    }
  }
}
