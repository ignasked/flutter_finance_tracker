import 'package:flutter/material.dart';
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
}
