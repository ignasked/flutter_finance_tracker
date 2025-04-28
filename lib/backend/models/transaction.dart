import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:objectbox/objectbox.dart';
import 'category.dart'; // Import the Category model

@Entity()

/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
// ignore: must-be-immutable
class Transaction extends Equatable {
  @Id()
  int id;

  final String title;
  final double amount;
  final String? description; // Optional description

  // Define a relation to the Category model
  final ToOne<Category> category = ToOne<Category>();
  final ToOne<Account> account = ToOne<Account>(); // Relation to Account

  @Property(type: PropertyType.date)
  final DateTime date;

  Transaction({
    this.id = 0,
    required this.title,
    required this.amount,
    this.description,
    required this.date,
    Category? category,
    Account? account,
  }) {
    if (category != null) {
      this.category.target = category;
    }
    if (account != null) {
      this.account.target = account;
    }
  }

  /// Getter to determine if the transaction is income or expense based on the category
  bool get isIncome {
    return category.target?.type == TransactionType.income;
  }

  @override
  List<Object?> get props => [
        id,
        title,
        amount,
        isIncome,
        category.target,
        account.target,
        date,
        description
      ];

  /// Creates a copy of this transaction with updated fields.
  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    Category? category,
    Account? account,
    DateTime? date,
    String? description,
  }) {
    final updatedTransaction = Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
    );
    updatedTransaction.category.target = category ?? this.category.target;
    updatedTransaction.account.target = account ?? this.account.target;
    return updatedTransaction;
  }

  static String toCSVHeader() {
    return 'id,title,description,amount,isIncome,category,account,date';
  }

  String toCSV() {
    return '$id,$title,${description ?? ''},$amount,$isIncome,${category.target?.id},${account.target?.id},$date';
  }

  static Transaction fromCSV(String csv) {
    List<String> fields = csv.split(',');
    if (fields.length != 6) {
      throw Exception('Invalid CSV format');
    }
    // Parse the fields and create a Transaction object
    return Transaction(
      id: int.parse(fields[0]),
      title: fields[1],
      description: fields[2].isNotEmpty ? fields[2] : null,
      amount: double.parse(fields[3]),
      date: DateTime.parse(fields[7]),
      category: null, // TODO: Implement proper Category parsing from CSV
      account: null, // TODO: Implement proper Account parsing from CSV
    );
  }

  // Factory method to create a Transaction from JSON
  factory Transaction.fromJson(
      Map<String, dynamic> json, CategoryRepository categoryRepository) {
    Category? category;
    if (json['categoryId'] != null) {
      category = categoryRepository.box.get(json['categoryId']);
      // if (category != null) {
      //   transaction.category.target = category;
      // }
    }

    if (json['accountId'] != null) {
      // transaction.account.target = Account(
      //   id: json['accountId'],
      //   name: json['accountName'] ?? 'Unknown Account',
      //   currency: json['accountCurrency'] ?? 'USD',
      //   iconCodePoint: json['accountIconCodePoint'] ?? 0,
      //   colorValue: json['accountColorValue'] ?? 0xFF000000,
      //   typeValue: json['accountTypeValue'] ?? 0,
      //   balance: json['accountBalance'] ?? 0.0,
      // );
    }

    final transaction = Transaction(
      id: json['id'] as int? ?? 0,
      title: json['title'] as String? ?? 'Unknown',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      date: _parseDate(json['date']),
      category: category,
    );

    return transaction;
  }

  // Helper method for safe date parsing
  static DateTime _parseDate(dynamic date) {
    try {
      return date != null ? DateTime.parse(date.toString()) : DateTime.now();
    } catch (e) {
      return DateTime.now(); // Fallback to current date if parsing fails
    }
  }

  // Convert a Transaction object to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'description': description,
      'amount': amount,
      'isIncome': isIncome, // Derived from the category
      'categoryId': category.targetId, // Save the category ID
      'accountId': account.targetId, // Save the account ID
      'date': date.toIso8601String(),
    };
  }
}
