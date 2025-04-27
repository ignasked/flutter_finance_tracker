import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/utils/enums.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/category.dart';
import 'package:flutter/material.dart';

class CategoryRepository extends BaseRepository<Category> {
  CategoryRepository(Store store) : super(store) {
    _initializeDefaultCategories();
  }

  /// Factory method for asynchronous initialization
  static Future<CategoryRepository> create([Store? store]) async {
    final newStore = store ?? await BaseRepository.createStore();
    return CategoryRepository(newStore);
  }

  /// Check if a category title is unique
  bool isTitleUnique(String title) {
    try {
      final query = box.query(Category_.title.equals(title)).build();
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
      final query = box.query(Category_.isEnabled.equals(true)).build();
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

    // Add only missing categories
    for (final defaultCategory in defaultCategories) {
      final query =
          box.query(Category_.title.equals(defaultCategory.title)).build();
      final exists = query.find().isNotEmpty;
      query.close();

      if (!exists) {
        try {
          box.put(defaultCategory);
          print('Added default category: ${defaultCategory.title}');
        } catch (e) {
          print('Error adding default category ${defaultCategory.title}: $e');
        }
      }
    }
  }
}
