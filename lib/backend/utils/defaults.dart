import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/account.dart';
import '../models/category.dart';

class Defaults {
  // Singleton instance
  static final Defaults _instance = Defaults._internal();

  factory Defaults() {
    return _instance;
  }

  Defaults._internal() {
    loadDefaults();
  }

  // Default account
  Account defaultAccount = Account(
    name: 'Bank Account',
    currency: 'USD',
    iconCodePoint: Icons.account_balance.codePoint,
    colorValue: Colors.blue.value,
    typeValue: 1,
  );

  // Default category
  Category defaultCategory = Category(
    title: 'Uncategorized',
    descriptionForAI: "Uncategorized transactions",
    iconCodePoint: Icons.category.codePoint,
    colorValue: Colors.grey.value,
    typeValue: 1,
    isEnabled: false,
  );

  // Default currency
  String defaultCurrency = 'USD';
  String defaultCurrencySymbol = '\$';

  DateTime defaultDateRangeStart =
      DateTime.now().subtract(const Duration(days: 30));
  DateTime defaultDateRangeEnd = DateTime.now();

  Future<void> saveDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('defaultCurrency', defaultCurrency);
    await prefs.setString('defaultCurrencySymbol', defaultCurrencySymbol);
    await prefs.setInt('defaultAccount', defaultAccount.id);
    await prefs.setInt('defaultCategory', defaultCategory.id);
  }

  Future<void> loadDefaults() async {
    final prefs = await SharedPreferences.getInstance();
    defaultCurrency = prefs.getString('defaultCurrency') ?? 'USD';
    defaultCurrencySymbol = prefs.getString('defaultCurrencySymbol') ?? '\$';
  }
}
