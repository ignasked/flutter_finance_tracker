import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:objectbox/objectbox.dart';
import 'category.dart'; // Import the Category model

@Entity()
// ignore: must_be_immutable
/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
class Transaction extends Equatable {
  @Id(assignable: true) // <-- Add assignable: true
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
  final DateTime createdAt; // Add 'final' back

  @Property(type: PropertyType.date)
  final DateTime updatedAt; // Add 'final' back

  // Add userId field
  @Index() // Index for faster lookups by userId
  final String? userId;

  // Add a transient field for metadata (not stored in database)
  @Transient()
  Map<String, dynamic>? metadata;

  // Add deletedAt field
  @Property(type: PropertyType.date)
  @Index()
  DateTime? deletedAt; // Nullable: Tracks deletion time (UTC)

  String get amountAndCurrencyString {
    return '${amount.toStringAsFixed(2)} ${fromAccount.target?.currencySymbolOrCurrency ?? ''}';
  }

  /// Getter to determine if the transaction is income or expense based on the category
  bool get isIncome {
    return category.target?.type == TransactionType.income;
  }

  /// Getter to determine if the transaction is deleted
  bool get isDeleted => deletedAt != null;

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
    this.deletedAt, // Add deletedAt parameter
  })  : id = id ?? 0,
        // Initialize final fields in initializer list
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now()) {
    // Constructor body remains the same for relationship assignment
    if (category != null) {
      this.category.target = category;
    }
    if (fromAccount != null) {
      this.fromAccount.target = fromAccount;
    }
    if (toAccount != null) {
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
        deletedAt,
      ];

  /// Creates a copy of this transaction with updated fields.
  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    Category? category, // Keep accepting objects for convenience elsewhere
    int? categoryId, // Add ID parameters for sync logic
    Account? fromAccount, // Keep accepting objects
    int? fromAccountId, // Add ID parameters
    Account? toAccount, // Keep accepting objects
    int? toAccountId, // Add ID parameters
    DateTime? date,
    String? description,
    DateTime? createdAt, // Keep accepting DateTime
    DateTime? updatedAt, // Keep accepting DateTime
    String? userId,
    Map<String, dynamic>? metadata,
    DateTime? deletedAt,
    bool? setDeletedAtNull,
  }) {
    // Create the new instance with updated primitive/DateTime fields
    final updatedTransaction = Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
      description: description ?? this.description,
      // Use provided timestamps or existing ones
      createdAt: createdAt ?? this.createdAt,
      // Always update 'updatedAt' on copy unless explicitly provided
      updatedAt: updatedAt ?? DateTime.now(),
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
      deletedAt:
          setDeletedAtNull == true ? null : (deletedAt ?? this.deletedAt),
      // Pass relationship objects ONLY if they were explicitly provided
      // Otherwise, we'll set IDs below
      category: category,
      fromAccount: fromAccount,
      toAccount: toAccount,
    );

    // --- Handle Relationship IDs ---
    // Prioritize passed objects, then passed IDs, then existing IDs.

    // Category
    if (category == null) {
      // If no Category object was passed
      updatedTransaction.category.targetId =
          categoryId ?? this.category.targetId;
    } // else: constructor already set the target from the passed object

    // FromAccount
    if (fromAccount == null) {
      // If no fromAccount object was passed
      updatedTransaction.fromAccount.targetId =
          fromAccountId ?? this.fromAccount.targetId;
    } // else: constructor already set the target

    // ToAccount
    if (toAccount == null) {
      // If no toAccount object was passed
      updatedTransaction.toAccount.targetId =
          toAccountId ?? this.toAccount.targetId;
    } // else: constructor already set the target

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
        deletedAt: json['deleted_at'] == null
            ? null
            : DateTime.tryParse(json['deleted_at'] as String)
                ?.toLocal(), // Add deletedAt (local)
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
      'deleted_at': deletedAt?.toUtc().toIso8601String(), // Add deletedAt (UTC)
    };
  }
}
