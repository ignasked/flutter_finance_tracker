import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/enums.dart';
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
        colorValue: Colors.orange.value,
        iconCodePoint: Icons.restaurant.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Transportation',
        descriptionForAI:
            'Expenses related to transportation like fuel, public transit, taxis',
        colorValue: Colors.blue.value,
        iconCodePoint: Icons.directions_car.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Accomodation',
        descriptionForAI: 'Expenses related to housing, rent, hotels',
        colorValue: Colors.brown.value,
        iconCodePoint: Icons.home.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Groceries',
        descriptionForAI:
            'Expenses related to grocery shopping and household supplies',
        colorValue: Colors.green.value,
        iconCodePoint: Icons.shopping_cart.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Junk Food',
        descriptionForAI: 'Expenses related to snacks and fast food',
        colorValue: Colors.red.value,
        iconCodePoint: Icons.fastfood.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Services',
        descriptionForAI:
            'Expenses related to various services and subscriptions',
        colorValue: Colors.indigo.value,
        iconCodePoint: Icons.miscellaneous_services.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Fitness',
        descriptionForAI:
            'Expenses related to gym memberships and fitness activities',
        colorValue: Colors.deepOrange.value,
        iconCodePoint: Icons.fitness_center.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Entertainment',
        descriptionForAI:
            'Expenses related to entertainment and leisure activities',
        colorValue: Colors.purple.value,
        iconCodePoint: Icons.sports_esports.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Healthcare',
        descriptionForAI:
            'Expenses related to medical care and health services',
        colorValue: Colors.red.value,
        iconCodePoint: Icons.local_hospital.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Utilities',
        descriptionForAI:
            'Expenses related to utilities like electricity, water, internet',
        colorValue: Colors.blue.value,
        iconCodePoint: Icons.power.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Clothing',
        descriptionForAI: 'Expenses related to clothes and accessories',
        colorValue: Colors.pink.value,
        iconCodePoint: Icons.shopping_bag.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Deposit',
        descriptionForAI: 'Money deposited or saved from bottle returns',
        colorValue: Colors.amber.value,
        iconCodePoint: Icons.recycling.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Other Expenses',
        descriptionForAI:
            'Miscellaneous expenses that don\'t fit other categories',
        colorValue: Colors.grey.value,
        iconCodePoint: Icons.more_horiz.codePoint,
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Salary',
        descriptionForAI: 'Regular income from employment',
        colorValue: Colors.green.value,
        iconCodePoint: Icons.work.codePoint,
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Gifts',
        descriptionForAI: 'Recieved gifts',
        colorValue: Colors.pink.value,
        iconCodePoint: Icons.card_giftcard.codePoint,
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Side Hustle',
        descriptionForAI: 'Income from side jobs or freelance work',
        colorValue: Colors.teal.value,
        iconCodePoint: Icons.business_center.codePoint,
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Other Income',
        descriptionForAI:
            'Miscellaneous income that doesn\'t fit other categories',
        colorValue: Colors.grey.value,
        iconCodePoint: Icons.more_horiz.codePoint,
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Discount',
        descriptionForAI: 'Money saved through discounts and rebates',
        colorValue: Colors.green.value,
        iconCodePoint: Icons.local_offer.codePoint,
        typeValue: TransactionType.income.index,
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
