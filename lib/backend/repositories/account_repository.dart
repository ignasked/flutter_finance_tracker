import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/base_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:money_owl/objectbox.g.dart';
import 'package:money_owl/backend/services/sync_service.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AccountRepository extends BaseRepository<Account> {
  AccountRepository(Store store) : super(store) {
    _initializeDefaultAccounts();
    _setDefaultAccount();
  }

  Future<void> _setDefaultAccount() async {
    final defaultAcc = await getById(1);
    if (defaultAcc != null) {
      Defaults().defaultAccount = defaultAcc;
    }
  }

  /// Factory method for asynchronous initialization
  static Future<AccountRepository> create([Store? store]) async {
    final newStore = store ?? await BaseRepository.createStore();
    return AccountRepository(newStore);
  }

  Future<void> _initializeDefaultAccounts() async {
    final isFirstLaunch = await _isFirstLaunch();
    if (!isFirstLaunch) {
      final defaultAcc = await getById(1);
      if (defaultAcc != null) {
        Defaults().defaultAccount = defaultAcc;
      }
      return;
    }
    final defaultAccounts = [
      Account(
        name: 'Bank Account',
        typeValue: AccountType.bank.index,
        currency: 'USD',
        currencySymbol: '\$',
        balance: 0.0,
        colorValue: Colors.blue.value,
        iconCodePoint: Icons.account_balance.codePoint,
      ),
      Account(
        name: 'Cash',
        typeValue: AccountType.cash.index,
        currency: 'USD',
        currencySymbol: '\$',
        balance: 0.0,
        colorValue: Colors.green.value,
        iconCodePoint: Icons.account_balance_wallet.codePoint,
      ),
    ];

    for (Account defaultAccount in defaultAccounts) {
      final supabase = Supabase.instance.client;
      defaultAccount =
          defaultAccount.copyWith(userId: supabase.auth.currentUser?.id);

      final query =
          box.query(Account_.name.equals(defaultAccount.name)).build();
      final exists = query.find().isNotEmpty;
      query.close();

      if (!exists) {
        try {
          await put(defaultAccount);
          print('Added default account: ${defaultAccount.name}');
        } catch (e) {
          print('Error adding default account ${defaultAccount.name}: $e');
        }
      }
    }

    final defaultAcc = await getById(1);
    if (defaultAcc != null) {
      Defaults().defaultAccount = defaultAcc;
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

  /// Get accounts modified after a specific time (UTC).
  Future<List<Account>> getAllModifiedSince(DateTime time) async {
    final query = box
        .query(Account_.updatedAt > time.toUtc().millisecondsSinceEpoch)
        .build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  Future<List<Account>> getAllEnabled() async {
    final query = box.query(Account_.isEnabled.equals(true)).build();
    final results = await query.findAsync();
    query.close();
    return results;
  }

  /// Override put to update timestamps before saving.
  @override
  Future<int> put(Account account,
      {SyncSource syncSource = SyncSource.local}) async {
    if (syncSource == SyncSource.local) {
      final now = DateTime.now();
      Account accountToSave;
      if (account.id == 0) {
        accountToSave = account.copyWith(createdAt: now, updatedAt: now);
      } else {
        accountToSave = account.copyWith(updatedAt: now);
      }
      final savedId = await super.put(accountToSave, syncSource: syncSource);
      return savedId;
    } else {
      return await super.put(account, syncSource: syncSource);
    }
  }
}
