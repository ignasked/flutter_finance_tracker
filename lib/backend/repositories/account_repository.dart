import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../objectbox.g.dart'; // ObjectBox generated file

class AccountRepository extends BaseRepository<Account> {
  AccountRepository(Store store) : super(store) {
    _initializeDefaultAccounts();
    final defaultAcc = getById(1);
    if (defaultAcc != null) {
      Defaults().defaultAccount = defaultAcc; // Set default account
    }
  }

  /// Factory method for asynchronous initialization
  static Future<AccountRepository> create([Store? store]) async {
    final newStore = store ?? await BaseRepository.createStore();
    return AccountRepository(newStore);
  }

  Future<void> _initializeDefaultAccounts() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) return;

    final defaultAccounts = [
      Account(
        name: 'Bank Account',
        typeValue: AccountType.bank.index, // Convert enum to int
        currency: 'USD',
        balance: 0.0,
        colorValue: Colors.blue.value, // Convert Color to int
        iconCodePoint:
            Icons.account_balance.codePoint, // Convert IconData to int
      ),
      Account(
        name: 'Cash',
        typeValue: AccountType.cash.index, // Convert enum to int
        currency: 'USD',
        balance: 0.0,
        colorValue: Colors.green.value, // Convert Color to int
        iconCodePoint:
            Icons.account_balance_wallet.codePoint, // Convert IconData to int
      ),
    ];

    // Add only missing accounts
    for (final defaultAccount in defaultAccounts) {
      final query =
          box.query(Account_.name.equals(defaultAccount.name)).build();
      final exists = query.find().isNotEmpty;
      query.close();

      if (!exists) {
        try {
          box.put(defaultAccount);
          print('Added default account: ${defaultAccount.name}');
        } catch (e) {
          print('Error adding default account ${defaultAccount.name}: $e');
        }
      }
    }

    final defaultAcc = getById(1);
    if (defaultAcc != null) {
      Defaults().defaultAccount = defaultAcc; // Set default account
    }
  }

  Future<bool> _isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    final isFirstLaunch = prefs.getBool('isFirstLaunchAccounts') ?? true;
    if (isFirstLaunch) {
      await prefs.setBool('isFirstLaunchAccounts', false);
    }
    return isFirstLaunch;
  }
}
