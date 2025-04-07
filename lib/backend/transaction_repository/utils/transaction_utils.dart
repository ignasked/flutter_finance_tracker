import 'package:pvp_projektas/backend/models/transaction.dart';

final categories = [
  'Food',
  'Travel',
  'Taxes',
  'Salary',
  'Other'
]; // Kodel string? Galimybe redaguot kategorijas useriui, bet kai treniruosiu kategorizavimo modeli tai nesigaus su redaguotom kategorijom

double calculateBalance(List<Transaction> transactions) {
  return transactions.fold(
    0.0,
    (balance, transaction) =>
        balance +
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

//TODO: move filters to separate script
//TODO: refactor filters for proper decorator pattern

abstract class TransactionFilter {
  List<Transaction> filter(List<Transaction> transactions);
}

class BaseTransactionFilter implements TransactionFilter {
  @override
  List<Transaction> filter(List<Transaction> transactions) {
    return transactions; // No filtering applied
  }
}

class TypeFilterDecorator implements TransactionFilter {
  final bool isIncome;

  TypeFilterDecorator({required this.isIncome});

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.isIncome == isIncome)
        .toList();
  }
}

class DateFilterDecorator implements TransactionFilter {
  final DateTime startDate;
  final DateTime endDate;

  DateFilterDecorator({required this.startDate, required this.endDate});

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    return transactions
        .where((transaction) =>
            transaction.date.isAfter(startDate) &&
            transaction.date.isBefore(endDate))
        .toList();
  }
}

class AmountFilterDecorator implements TransactionFilter {
  final double minAmount;

  AmountFilterDecorator({required this.minAmount});

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    return transactions
        .where((transaction) => transaction.amount.abs() >= minAmount)
        .toList();
  }
}

class CategoryFilterDecorator implements TransactionFilter {
  final List<String> categories;

  CategoryFilterDecorator({required this.categories});

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    // Keep transactions whose category is in the list
    return transactions
        .where((tx) => categories.contains(tx.category))
        .toList();
  }
}
