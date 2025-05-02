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

  // Add a transient field for metadata (not stored in database)
  @Transient()
  Map<String, dynamic>? metadata;

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
    this.metadata, // Add metadata parameter
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
        // Use target?.id instead of targetId to avoid the initialization error
        category.target?.id,
        fromAccount.target?.id,
        toAccount.target?.id,
        date,
        description,
        createdAt,
        updatedAt,
        userId,
        metadata,
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
    Map<String, dynamic>? metadata, // Add metadata parameter
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
      metadata: metadata ?? this.metadata, // Copy metadata
    );
    updatedTransaction.category.target = category ?? this.category.target;
    updatedTransaction.fromAccount.target =
        fromAccount ?? this.fromAccount.target;
    updatedTransaction.toAccount.target = toAccount ?? this.toAccount.target;
    return updatedTransaction;
  }

  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Use safer type checking with ?? default values to handle missing or malformed data
    try {
      final transaction = Transaction(
        id: json['id'] is int ? json['id'] : 0,
        title: json['title'] is String ? json['title'] as String : 'Untitled',
        amount:
            json['amount'] is num ? (json['amount'] as num).toDouble() : 0.0,
        description: json['description'] is String
            ? json['description'] as String?
            : null,
        date: json['date'] is String
            ? DateTime.tryParse(json['date'] as String)?.toLocal() ??
                DateTime.now()
            : DateTime.now(),
        createdAt: json['created_at'] is String
            ? DateTime.tryParse(json['created_at'] as String)?.toLocal() ??
                DateTime.now()
            : DateTime.now(),
        updatedAt: json['updated_at'] is String
            ? DateTime.tryParse(json['updated_at'] as String)?.toLocal() ??
                DateTime.now()
            : DateTime.now(),
        userId: json['user_id'] is String ? json['user_id'] as String : null,
        metadata: json['metadata'] is Map<String, dynamic>
            ? json['metadata'] as Map<String, dynamic>
            : null, // Parse metadata
      );

      // Safely assign relationship IDs with null checks
      // Check both standard format (from_account_id) and camelCase format (fromAccountId)
      if (json['from_account_id'] is int) {
        transaction.fromAccount.targetId = json['from_account_id'] as int;
      } else if (json['fromAccountId'] is int) {
        transaction.fromAccount.targetId = json['fromAccountId'] as int;
      }

      // Check both snake_case and camelCase formats for category_id
      if (json['category_id'] is int) {
        transaction.category.targetId = json['category_id'] as int;
      } else if (json['categoryId'] is int) {
        transaction.category.targetId = json['categoryId'] as int;
      }

      if (json['to_account_id'] is int) {
        transaction.toAccount.targetId = json['to_account_id'] as int;
      } else if (json['toAccountId'] is int) {
        transaction.toAccount.targetId = json['toAccountId'] as int;
      }

      return transaction;
    } catch (e) {
      // Log the error for debugging
      print('Error parsing transaction JSON: $e');
      print('Problematic JSON: $json');

      // Return a minimal valid transaction to prevent crashes
      return Transaction(
        title: 'Error: Invalid Data',
        amount: 0,
        date: DateTime.now(),
      );
    }
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id == 0 ? null : id,
      'title': title,
      'description': description,
      'amount': amount,
      'category_id': category.target != null ? category.targetId : null,
      'from_account_id':
          fromAccount.target != null ? fromAccount.targetId : null,
      'to_account_id': toAccount.target != null ? toAccount.targetId : null,
      'date': date.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'user_id': userId, // Include userId in JSON
      'metadata': metadata, // Include metadata in JSON
    };
  }
}
