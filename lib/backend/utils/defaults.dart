import 'package:flutter/material.dart';
import '../models/account.dart';
import '../models/category.dart';

class Defaults {
  // Singleton instance
  static final Defaults _instance = Defaults._internal();

  factory Defaults() {
    return _instance;
  }

  Defaults._internal();

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
}
