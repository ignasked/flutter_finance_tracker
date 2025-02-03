import 'package:pvp_projektas/backend/models/transaction.dart';

double calculateBalance(List<Transaction> transactions) {
  return transactions.fold(
    0.0,
        (balance, transaction) => balance +
        (transaction.isIncome ? transaction.amount : -transaction.amount),
  );
}

double calculateIncome(List<Transaction> transactions) {
  return transactions
      .where((transaction) => transaction.isIncome)
      .fold(0.0, (sum, transaction) => sum + transaction.amount);
}

double calculateExpenses(List<Transaction> transactions) {
  return transactions
      .where((transaction) => !transaction.isIncome)
      .fold(0.0, (sum, transaction) => sum + transaction.amount);
}
