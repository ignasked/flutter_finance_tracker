import 'package:flutter/material.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/category.dart';

class Defaults {
  // Singleton instance
  static final Defaults _instance = Defaults._internal();

  factory Defaults() {
    return _instance;
  }

  // Private constructor for internal use
  Defaults._internal();

  // --- Default Account ---
  Account? _defaultAccount;
  int? _defaultAccountId;

  Account get defaultAccount {
    if (_defaultAccount == null) {
      print(
          "Warning: Accessing defaultAccount before it's fully initialized by the repository.");
      return _createPlaceholderAccount();
    }
    return _defaultAccount!;
  }

  int? get defaultAccountId {
    if (_defaultAccountId == null) {
      print(
          "Warning: Accessing defaultAccountId before it's fully initialized by the repository.");
      return 0; // Placeholder ID
    }
    return _defaultAccountId!;
  }

  void setDefaultAccountInstance(Account? account) {
    // Allow null in case default is deleted
    if (account != null) {
      print(
          "Defaults: Setting default account instance (ID: ${account.id}, Name: ${account.name})");
      _defaultAccount = account;
      _defaultAccountId = account.id;
    } else {
      print(
          "Defaults: Default account ID $_defaultAccountId not found or deleted. Clearing default account instance.");
      _defaultAccount = null; // Clear if not found
      // Keep _defaultAccountId as loaded, maybe user needs to select a new one
      // If the account instance is explicitly set to null (e.g., user unsets default),
      // we should also clear the stored ID.
      _defaultAccountId = null;
    }
    // Save the ID change immediately
    saveDefaults();
  }

  Account _createPlaceholderAccount() {
    return Account(
      id: _defaultAccountId ?? 0,
      uuid: 'placeholder-uuid-account',
      name: 'Loading Account...',
      currency: defaultCurrency,
      currencySymbol: defaultCurrencySymbol,
      iconCodePoint: Icons.hourglass_empty.codePoint,
      colorValue: Colors.grey.value,
      typeValue: AccountType.bank.index,
    );
  }

  // --- Default Category ---
  Category? _defaultCategory; // Instance variable
  int? _defaultCategoryId; // Store the ID loaded from prefs

  // Public getter for the default category instance
  Category get defaultCategory {
    if (_defaultCategory == null) {
      print(
          "Warning: Accessing defaultCategory before it's fully initialized by the repository.");
      return _createPlaceholderCategory();
    }
    return _defaultCategory!;
  }

  int? get defaultCategoryId {
    if (_defaultCategoryId == null) {
      print(
          "Warning: Accessing defaultCategoryId before it's fully initialized by the repository.");
      return 0; // Placeholder ID
    }
    return _defaultCategoryId!;
  }

  // Method for CategoryRepository to set the actual default category instance
  void setDefaultCategoryInstance(Category? category) {
    // Allow null
    if (category != null) {
      print(
          "Defaults: Setting default category instance (ID: ${category.id}, Title: ${category.title})");
      _defaultCategory = category;
      _defaultCategoryId = category.id;
    } else {
      print(
          "Defaults: Default category ID $_defaultCategoryId not found or deleted. Clearing default category instance.");
      _defaultCategory = null; // Clear if not found
    }
  }

  // Helper to create a placeholder category
  Category _createPlaceholderCategory() {
    return Category(
      id: _defaultCategoryId ?? 0, // Use loaded ID if available
      uuid: 'placeholder-uuid-category', // Indicate it's a placeholder
      title: 'Loading Category...',
      descriptionForAI: "Loading default category",
      iconCodePoint: Icons.hourglass_empty.codePoint,
      colorValue: Colors.grey.value,
      typeValue: 1, // Default to expense type? Or make it neutral?
      isEnabled: false, // Placeholder shouldn't be considered enabled
    );
  }

  // --- Default Currency ---
  String defaultCurrency = 'USD';
  String defaultCurrencySymbol = '\$';

  // --- Default Date Range ---
  DateTime defaultDateRangeStart =
      DateTime.now().subtract(const Duration(days: 30));
  DateTime defaultDateRangeEnd = DateTime.now();

  // --- SharedPreferences Keys ---
  static const String _defaultCurrencyKey = 'defaultCurrency';
  static const String _defaultCurrencySymbolKey = 'defaultCurrencySymbol';
  static const String _defaultAccountIdKey = 'defaultAccountId';
  static const String _defaultCategoryIdKey = 'defaultCategoryId';

  /// Saves the IDs and currency settings to SharedPreferences.
  Future<void> saveDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_defaultCurrencyKey, defaultCurrency);
    await prefs.setString(_defaultCurrencySymbolKey, defaultCurrencySymbol);
    // Save the *currently set* default IDs
    if (_defaultAccountId != null) {
      await prefs.setInt(_defaultAccountIdKey, _defaultAccountId!);
      print("Defaults: Saved default Account ID: $_defaultAccountId");
    } else {
      await prefs.remove(_defaultAccountIdKey); // Remove if null
      print("Defaults: Removed default Account ID from prefs.");
    }
    if (_defaultCategoryId != null) {
      await prefs.setInt(_defaultCategoryIdKey, _defaultCategoryId!);
      print("Defaults: Saved default Category ID: $_defaultCategoryId");
    } else {
      await prefs.remove(_defaultCategoryIdKey); // Remove if null
      print("Defaults: Removed default Category ID from prefs.");
    }
  }

  /// Loads settings (currency, default IDs) from SharedPreferences.
  /// This should be called early, e.g., before repositories are created.
  Future<void> loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    defaultCurrency = prefs.getString(_defaultCurrencyKey) ?? 'USD';
    defaultCurrencySymbol = prefs.getString(_defaultCurrencySymbolKey) ?? '\$';
    // Load IDs, but don't try to load the full objects here
    _defaultAccountId = prefs.getInt(_defaultAccountIdKey);
    _defaultCategoryId = prefs.getInt(_defaultCategoryIdKey);

    print(
        "Defaults: Loaded settings - Currency: $defaultCurrency, AccountID: $_defaultAccountId, CategoryID: $_defaultCategoryId");

    // Reset instances so repositories can set them after loading
    _defaultAccount = null;
    _defaultCategory = null;
  }

  // --- Methods to update defaults (e.g., from Settings screen) ---

  // Updates the default account ID and saves immediately.
  // The instance will be updated next time the repository initializes or manually if needed.
  Future<void> updateDefaultAccountId(int? accountId) async {
    print("Defaults: Updating default account ID to $accountId");
    _defaultAccountId = accountId;
    // Save the ID change immediately
    await saveDefaults();
    // Clear the current instance so the placeholder shows until re-init
    _defaultAccount = null;
  }

  // Updates the default category ID and saves immediately.
  Future<void> updateDefaultCategoryId(int? categoryId) async {
    print("Defaults: Updating default category ID to $categoryId");
    _defaultCategoryId = categoryId;
    await saveDefaults();
    // Clear the current instance
    _defaultCategory = null;
  }

  List<Category> get defaultCategoriesData => [
        Category(
          title: 'Food',
          descriptionForAI: 'Expenses related to food and dining',
          colorValue: AppStyle.predefinedColors[3].value, // Orange
          iconCodePoint:
              AppStyle.predefinedIcons[7].codePoint, // restaurant_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Transportation',
          descriptionForAI:
              'Expenses related to transportation like fuel, public transit, taxis',
          colorValue: AppStyle.predefinedColors[1].value, // Blue
          iconCodePoint: AppStyle
              .predefinedIcons[2].codePoint, // directions_car_filled_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Accomodation',
          descriptionForAI: 'Expenses related to housing, rent, hotels',
          colorValue: AppStyle.predefinedColors[6].value, // Brown
          iconCodePoint: AppStyle.predefinedIcons[9].codePoint, // home_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Groceries',
          descriptionForAI:
              'Expenses related to grocery shopping and household supplies',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint:
              AppStyle.predefinedIcons[8].codePoint, // shopping_cart_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Junk Food',
          descriptionForAI: 'Expenses related to snacks and fast food',
          colorValue: AppStyle.predefinedColors[0].value, // Red
          iconCodePoint:
              AppStyle.predefinedIcons[1].codePoint, // fastfood_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Services',
          descriptionForAI:
              'Expenses related to various services and subscriptions',
          colorValue: AppStyle.predefinedColors[11].value, // Indigo
          iconCodePoint: AppStyle
              .predefinedIcons[10].codePoint, // miscellaneous_services_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Fitness',
          descriptionForAI:
              'Expenses related to gym memberships and fitness activities',
          colorValue: AppStyle.predefinedColors[10].value, // Deep Orange
          iconCodePoint:
              AppStyle.predefinedIcons[11].codePoint, // fitness_center_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Entertainment',
          descriptionForAI:
              'Expenses related to entertainment and leisure activities',
          colorValue: AppStyle.predefinedColors[4].value, // Purple
          iconCodePoint:
              AppStyle.predefinedIcons[12].codePoint, // sports_esports_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Healthcare',
          descriptionForAI:
              'Expenses related to medical care and health services',
          colorValue: AppStyle.predefinedColors[0].value, // Red
          iconCodePoint:
              AppStyle.predefinedIcons[5].codePoint, // local_hospital_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Utilities',
          descriptionForAI:
              'Expenses related to utilities like electricity, water, internet',
          colorValue: AppStyle.predefinedColors[1].value, // Blue
          iconCodePoint:
              AppStyle.predefinedIcons[13].codePoint, // power_settings_new
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Clothing',
          descriptionForAI: 'Expenses related to clothes and accessories',
          colorValue: AppStyle.predefinedColors[5].value, // Pink
          iconCodePoint:
              AppStyle.predefinedIcons[14].codePoint, // shopping_bag_outlined
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Deposit', // Assuming this relates to recycling/returns
          descriptionForAI: 'Money deposited or saved from bottle returns',
          colorValue: AppStyle.predefinedColors[7].value, // Amber
          iconCodePoint:
              AppStyle.predefinedIcons[15].codePoint, // recycling_outlined
          typeValue: TransactionType
              .expense.index, // Should this be income? Keeping expense for now.
        ),
        Category(
          title: 'Other Expenses',
          descriptionForAI:
              'Miscellaneous expenses that don\'t fit other categories',
          colorValue: AppStyle.predefinedColors[8].value, // Grey
          iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // more_horiz
          typeValue: TransactionType.expense.index,
        ),
        Category(
          title: 'Salary',
          descriptionForAI: 'Regular income from employment',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint: AppStyle.predefinedIcons[4].codePoint, // attach_money
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Gifts',
          descriptionForAI: 'Recieved gifts',
          colorValue: AppStyle.predefinedColors[5].value, // Pink
          iconCodePoint:
              AppStyle.predefinedIcons[16].codePoint, // card_giftcard_outlined
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Side Hustle',
          descriptionForAI: 'Income from side jobs or freelance work',
          colorValue: AppStyle.predefinedColors[9].value, // Teal
          iconCodePoint: AppStyle
              .predefinedIcons[17].codePoint, // business_center_outlined
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Other Income',
          descriptionForAI:
              'Miscellaneous income that doesn\'t fit other categories',
          colorValue: AppStyle.predefinedColors[8].value, // Grey
          iconCodePoint: AppStyle.predefinedIcons[19].codePoint, // more_horiz
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Discount for item', // Using local_offer
          descriptionForAI: 'Money saved through discounts and rebates',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint:
              AppStyle.predefinedIcons[18].codePoint, // local_offer_outlined
          typeValue: TransactionType.income.index,
        ),
        Category(
          title: 'Overall discount', // Using local_offer
          descriptionForAI: 'Money saved through discounts and rebates',
          colorValue: AppStyle.predefinedColors[2].value, // Green
          iconCodePoint:
              AppStyle.predefinedIcons[18].codePoint, // local_offer_outlined
          typeValue: TransactionType.income.index,
        ),
      ];

  // Define default data with stable UUIDs
  List<Account> get defaultAccountsData => [
        Account(
          name: 'Bank Account',
          typeValue: AccountType.bank.index,
          currency: Defaults().defaultCurrency,
          currencySymbol: Defaults().defaultCurrencySymbol,
          balance: 0.0,
          colorValue: AppStyle.predefinedColors[0].value,
          iconCodePoint: AppStyle.predefinedIcons[20].codePoint,
        ),
        Account(
          name: 'Cash',
          typeValue: AccountType.cash.index,
          currency: Defaults().defaultCurrency,
          currencySymbol: Defaults().defaultCurrencySymbol,
          balance: 0.0,
          colorValue: AppStyle.predefinedColors[1].value,
          iconCodePoint: AppStyle.predefinedIcons[21].codePoint,
        )
      ];
}
