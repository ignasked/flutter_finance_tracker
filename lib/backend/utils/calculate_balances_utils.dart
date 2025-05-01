import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/defaults.dart';

class CalculateBalancesUtils {
  static Map<int, double> calculateAccountBalances(
      List<Transaction> transactions) {
    final Map<int, double> accountBalances = {};

    for (final transaction in transactions) {
      final accountId = transaction.fromAccount.targetId;
      final amount = transaction.amount;

      accountBalances[accountId] = (accountBalances[accountId] ?? 0.0) +
          (transaction.isIncome ? amount : -amount);
    }

    return accountBalances;
  }

  static Map<String, double> calculateIncomeByCurrency(
      List<Transaction> transactions) {
    final Map<String, double> incomeByCurrency = {};

    for (final transaction in transactions) {
      if (transaction.isIncome) {
        final currency = transaction.fromAccount.target?.currency ??
            Defaults().defaultCurrency;
        incomeByCurrency[currency] =
            (incomeByCurrency[currency] ?? 0.0) + transaction.amount;
      }
    }

    return incomeByCurrency;
  }

  static Map<String, double> calculateExpensesByCurrency(
      List<Transaction> transactions) {
    final Map<String, double> expensesByCurrency = {};

    for (final transaction in transactions) {
      if (!transaction.isIncome) {
        final currency = transaction.fromAccount.target?.currency ??
            Defaults().defaultCurrency;
        expensesByCurrency[currency] =
            (expensesByCurrency[currency] ?? 0.0) + transaction.amount;
      }
    }

    return expensesByCurrency;
  }
}
