import 'package:money_owl/backend/models/transaction.dart';

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
  final TransactionFilter? nextFilter;

  TransactionFilter({this.nextFilter});

  List<Transaction> filter(List<Transaction> transactions) {
    return nextFilter?.filter(transactions) ?? transactions;
  }
}

class BaseTransactionFilter extends TransactionFilter {
  BaseTransactionFilter() : super(nextFilter: null);

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    return transactions; // No filtering applied
  }
}

class TypeFilterDecorator extends TransactionFilter {
  final bool isIncome;

  TypeFilterDecorator({required this.isIncome, TransactionFilter? nextFilter})
      : super(nextFilter: nextFilter);

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    final filtered = transactions
        .where((transaction) => transaction.isIncome == isIncome)
        .toList();
    return super.filter(filtered);
  }
}

class DateFilterDecorator extends TransactionFilter {
  final DateTime startDate;
  final DateTime endDate;

  DateFilterDecorator({
    required this.startDate,
    required this.endDate,
    TransactionFilter? nextFilter,
  }) : super(nextFilter: nextFilter);

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    final filtered = transactions
        .where((transaction) =>
            transaction.date.isAfter(startDate) &&
            transaction.date.isBefore(endDate))
        .toList();
    return super.filter(filtered); // Delegate to the next filter
  }
}

class AmountFilterDecorator extends TransactionFilter {
  final double minAmount;

  AmountFilterDecorator(
      {required this.minAmount, TransactionFilter? nextFilter})
      : super(nextFilter: nextFilter);

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    final filtered = transactions
        .where((transaction) => transaction.amount.abs() >= minAmount)
        .toList();
    return super.filter(filtered); // Delegate to the next filter
  }
}

class CategoryFilterDecorator extends TransactionFilter {
  final List<int> categoryIds;

  CategoryFilterDecorator(
      {required this.categoryIds, TransactionFilter? nextFilter})
      : super(nextFilter: nextFilter);

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    final filtered = transactions.where((transaction) {
      final categoryId = transaction.category.target?.id;
      return categoryId != null && categoryIds.contains(categoryId);
    }).toList();
    return super.filter(filtered); // Delegate to the next filter
  }
}
