import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/transaction.dart';

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

class AccountFilterDecorator extends TransactionFilter {
  final Account account;

  AccountFilterDecorator({
    required this.account,
    TransactionFilter? nextFilter,
  }) : super(nextFilter: nextFilter);

  @override
  List<Transaction> filter(List<Transaction> transactions) {
    final filtered = transactions
        .where((transaction) => transaction.account.targetId == account.id)
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
            (transaction.date.year >= startDate.year &&
                transaction.date.month >= startDate.month &&
                transaction.date.day >= startDate.day) &&
            (transaction.date.year <= endDate.year &&
                transaction.date.month <= endDate.month &&
                transaction.date.day <= endDate.day))
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
