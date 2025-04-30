import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  @override
  void putById(int id, Category entity) {
    try {
      final existingEntity = box.get(id);
      if (existingEntity != null) {
        // Update the existing entity
        box.put(existingEntity.copyWith(
          title: entity.title,
          descriptionForAI: entity.descriptionForAI,
          colorValue: entity.colorValue,
          iconCodePoint: entity.iconCodePoint,
          typeValue: entity.typeValue,
          isEnabled: entity.isEnabled,
        ));
      } else {
        // Add the new entity
        box.put(entity);
      }
    } catch (e) {
      print('Error adding/updating entity by ID: $e');
    }
  }

  /// Initialize default categories
  Future<void> _initializeDefaultCategories() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) return;

    final defaultCategories = [
      Category(
        title: 'Food',
        descriptionForAI: 'Expenses related to food and dining',
        colorValue: AppStyle.predefinedColors[3].value, // Orange
        iconCodePoint: AppStyle.predefinedIcons[7].codePoint, // Restaurant
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Transportation',
        descriptionForAI:
            'Expenses related to transportation like fuel, public transit, taxis',
        colorValue: AppStyle.predefinedColors[1].value, // Blue
        iconCodePoint: AppStyle.predefinedIcons[2].codePoint, // Directions Car
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Accomodation',
        descriptionForAI: 'Expenses related to housing, rent, hotels',
        colorValue: AppStyle.predefinedColors[6].value, // Brown
        iconCodePoint: AppStyle.predefinedIcons[9].codePoint, // Home
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Groceries',
        descriptionForAI:
            'Expenses related to grocery shopping and household supplies',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[8].codePoint, // Shopping Cart
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Junk Food',
        descriptionForAI: 'Expenses related to snacks and fast food',
        colorValue: AppStyle.predefinedColors[0].value, // Red
        iconCodePoint: AppStyle.predefinedIcons[1].codePoint, // Fast Food
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Services',
        descriptionForAI:
            'Expenses related to various services and subscriptions',
        colorValue: AppStyle.predefinedColors[11].value, // Indigo
        iconCodePoint:
            AppStyle.predefinedIcons[10].codePoint, // Miscellaneous Services
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Fitness',
        descriptionForAI:
            'Expenses related to gym memberships and fitness activities',
        colorValue: AppStyle.predefinedColors[10].value, // Deep Orange
        iconCodePoint: AppStyle.predefinedIcons[11].codePoint, // Fitness Center
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Entertainment',
        descriptionForAI:
            'Expenses related to entertainment and leisure activities',
        colorValue: AppStyle.predefinedColors[4].value, // Purple
        iconCodePoint: AppStyle.predefinedIcons[12].codePoint, // Sports Esports
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Healthcare',
        descriptionForAI:
            'Expenses related to medical care and health services',
        colorValue: AppStyle.predefinedColors[0].value, // Red
        iconCodePoint: AppStyle.predefinedIcons[5].codePoint, // Local Hospital
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Utilities',
        descriptionForAI:
            'Expenses related to utilities like electricity, water, internet',
        colorValue: AppStyle.predefinedColors[1].value, // Blue
        iconCodePoint: AppStyle.predefinedIcons[13].codePoint, // Power
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Clothing',
        descriptionForAI: 'Expenses related to clothes and accessories',
        colorValue: AppStyle.predefinedColors[5].value, // Pink
        iconCodePoint: AppStyle.predefinedIcons[6].codePoint, // Shopping Bag
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Deposit',
        descriptionForAI: 'Money deposited or saved from bottle returns',
        colorValue: AppStyle.predefinedColors[7].value, // Amber
        iconCodePoint: AppStyle.predefinedIcons[14].codePoint, // Recycling
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Other Expenses',
        descriptionForAI:
            'Miscellaneous expenses that don\'t fit other categories',
        colorValue: AppStyle.predefinedColors[8].value, // Grey
        iconCodePoint: AppStyle.predefinedIcons[15].codePoint, // More Horiz
        typeValue: TransactionType.expense.index,
      ),
      Category(
        title: 'Salary',
        descriptionForAI: 'Regular income from employment',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[16].codePoint, // Work
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Gifts',
        descriptionForAI: 'Recieved gifts',
        colorValue: AppStyle.predefinedColors[5].value, // Pink
        iconCodePoint: AppStyle.predefinedIcons[17].codePoint, // Card Giftcard
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Side Hustle',
        descriptionForAI: 'Income from side jobs or freelance work',
        colorValue: AppStyle.predefinedColors[9].value, // Teal
        iconCodePoint:
            AppStyle.predefinedIcons[18].codePoint, // Business Center
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Other Income',
        descriptionForAI:
            'Miscellaneous income that doesn\'t fit other categories',
        colorValue: AppStyle.predefinedColors[8].value, // Grey
        iconCodePoint: AppStyle.predefinedIcons[15].codePoint, // More Horiz
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Discount for item',
        descriptionForAI: 'Money saved through discounts and rebates',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // Local Offer
        typeValue: TransactionType.income.index,
      ),
      Category(
        title: 'Overall discount',
        descriptionForAI: 'Money saved through discounts and rebates',
        colorValue: AppStyle.predefinedColors[2].value, // Green
        iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // Local Offer
        typeValue: TransactionType.income.index,
      ),
    ];

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

    final defaultCategory = getById(1);
    if (defaultCategory != null) {
      Defaults().defaultCategory = defaultCategory; // Set default account
    }
  }

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunch') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunch', false);
    }
    return isFirstLaunch;
  }
}
