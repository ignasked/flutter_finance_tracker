import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:objectbox/objectbox.dart';
import 'category.dart'; // Import the Category model

@Entity()
// ignore: must_be_immutable
/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
class Transaction extends Equatable {
  @Id()
  int id; // Remove 'final'

  final String title;
  final double amount;
  final String? description; // Optional description

  // Define a relation to the Category model
  final ToOne<Category> category = ToOne<Category>();
  final ToOne<Account> fromAccount = ToOne<Account>(); // Source Account
  final ToOne<Account> toAccount =
      ToOne<Account>(); // Destination Account (for transfers)

  @Property(type: PropertyType.date)
  final DateTime date;

  @Property(type: PropertyType.date)
  final DateTime createdAt;

  @Property(type: PropertyType.date)
  final DateTime updatedAt;

  // Add userId field
  final String? userId;

  String get amountAndCurrencyString {
    return '${amount.toStringAsFixed(2)} ${fromAccount.target?.currencySymbolOrCurrency ?? ''}';
  }

  /// Getter to determine if the transaction is income or expense based on the category
  bool get isIncome {
    return category.target?.type == TransactionType.income;
  }

  Transaction({
    int? id,
    required this.title,
    required this.amount,
    this.description,
    required this.date,
    Category? category,
    Account? fromAccount, // Renamed parameter
    Account? toAccount, // Added parameter
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId, // Add userId parameter
  })  : this.id = id ?? 0,
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? (createdAt ?? DateTime.now()) {
    if (category != null) {
      this.category.target = category;
    }
    if (fromAccount != null) {
      this.fromAccount.target = fromAccount;
    }
    if (toAccount != null) {
      // Assign target directly to the non-nullable ToOne
      this.toAccount.target = toAccount;
    }
  }

  @override
  List<Object?> get props => [
        id,
        title,
        amount,
        category.targetId,
        fromAccount.targetId,
        toAccount.targetId, // Use non-nullable targetId
        date,
        description,
        createdAt,
        updatedAt,
        userId, // Add userId to props
      ];

  /// Creates a copy of this transaction with updated fields.
  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    Category? category,
    Account? fromAccount, // Renamed parameter
    Account? toAccount,
    DateTime? date,
    String? description,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId, // Add userId parameter
  }) {
    final updatedTransaction = Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      fromAccount: fromAccount, // Pass fromAccount object
      toAccount: toAccount, // Pass toAccount object
      userId: userId ?? this.userId, // Copy userId
    );
    updatedTransaction.category.target = category ?? this.category.target;
    updatedTransaction.fromAccount.target =
        fromAccount ?? this.fromAccount.target;
    updatedTransaction.toAccount.target = toAccount ?? this.toAccount.target;
    return updatedTransaction;
  }

  static String toCSVHeader() {
    return 'id,title,description,amount,categoryId,categoryName,accountId,accountName,date,createdAt,updatedAt';
  }

  String toCSV() {
    return [
      id,
      title.replaceAll(',', ';'),
      (description ?? '').replaceAll(',', ';'),
      amount,
      category.target?.id ?? '',
      (category.target?.title ?? '').replaceAll(',', ';'),
      fromAccount.target?.id ?? '',
      (fromAccount.target?.name ?? '').replaceAll(',', ';'),
      date.toIso8601String(),
      createdAt.toIso8601String(),
      updatedAt.toIso8601String(),
    ].join(',');
  }

  static Transaction fromCSV(String csv) {
    List<String> fields = csv.split(',');
    if (fields.length < 9) {
      throw Exception('Invalid CSV format for Transaction');
    }

    return Transaction(
      id: int.parse(fields[0]),
      title: fields[1].replaceAll(';', ','),
      description: fields[2].isNotEmpty ? fields[2].replaceAll(';', ',') : null,
      amount: double.parse(fields[3]),
      date: DateTime.parse(fields[8]),
      createdAt: fields.length > 9 ? DateTime.tryParse(fields[9]) : null,
      updatedAt: fields.length > 10 ? DateTime.tryParse(fields[10]) : null,
    );
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    final transaction = Transaction(
      id: json['id'] as int,
      title: json['title'] as String,
      amount: (json['amount'] as num).toDouble(),
      description: json['description'] as String?,
      date: DateTime.parse(json['date'] as String).toLocal(),
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      userId: json['user_id'] as String?, // Read userId from JSON
    );
    transaction.fromAccount.targetId = json['from_account_id'] as int?;
    transaction.category.targetId = json['category_id'] as int?;
    transaction.toAccount.targetId =
        json['to_account_id'] as int?; // Read to_account_id
    return transaction;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id == 0 ? null : id,
      'title': title,
      'description': description,
      'amount': amount,
      'category_id': category.targetId,
      'from_account_id': fromAccount.targetId,
      'to_account_id':
          toAccount.targetId, // Add to_account_id (will be null if not set)
      'date': date.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'user_id': userId, // Include userId in JSON
    };
  }
}
