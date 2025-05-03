import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/objectbox.g.dart'; // Ensure this import exists
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart'; // Import uuid package

@Entity()
// ignore: must_be_immutable
/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
class Transaction extends Equatable {
  @Id()
  int id;

  @Index() // Index UUID for faster lookups during sync
  @Unique(onConflict: ConflictStrategy.replace) // Ensure UUID is unique locally
  String uuid; // Globally unique identifier

  final String title;
  final double amount;
  final String? description;
  @Property(type: PropertyType.date)
  final DateTime date;
  @Property(type: PropertyType.date)
  final DateTime createdAt;
  @Property(type: PropertyType.date)
  final DateTime? deletedAt; // Nullable: Tracks deletion time (UTC)
  DateTime updatedAt; // Make mutable for easier updates

  @Index()
  String? userId;

  // --- ToOne Relations ---
  // ObjectBox links these to the targetId stored internally
  final ToOne<Category> category = ToOne<Category>();
  final ToOne<Account> fromAccount = ToOne<Account>();
  final ToOne<Account> toAccount = ToOne<Account>(); //

  @Transient()
  Map<String, dynamic>? metadata;

  bool get isIncome => amount > 0;
  bool get isExpense => amount < 0;
  // Use targetId safely here as it's internal to ToOne
  bool get isTransfer => toAccount.targetId != 0;

  /// Getter to determine if the transaction is deleted
  bool get isDeleted => deletedAt != null;

  // --- Main Constructor (Used by ObjectBox) ---
  Transaction({
    this.id = 0, // ObjectBox will assign if 0
    String? uuid, // Accept optional UUID (e.g., from sync down)
    required this.title,
    required this.amount,
    this.description,
    required this.date,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.metadata,
    this.deletedAt,
  })  : uuid = uuid ?? const Uuid().v4(), // Generate UUID if not provided
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  // --- Factory Constructor (for convenience when creating with IDs) ---
  factory Transaction.createWithIds({
    int id = 0,
    String? uuid,
    required String title,
    required double amount,
    String? description,
    required DateTime date,
    required int categoryId, // IDs are required here
    required int fromAccountId,
    int? toAccountId,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    Map<String, dynamic>? metadata,
    DateTime? deletedAt,
  }) {
    // Create instance using the main constructor
    final transaction = Transaction(
      id: id,
      uuid: uuid,
      title: title,
      amount: amount,
      description: description,
      date: date,
      createdAt: createdAt,
      updatedAt: updatedAt,
      userId: userId,
      metadata: metadata,
      deletedAt: deletedAt,
    );
    // Manually set the target IDs after creation
    transaction.category.targetId = categoryId;
    transaction.fromAccount.targetId = fromAccountId;
    transaction.toAccount.targetId = toAccountId ?? 0;
    return transaction;
  }

  // --- Updated copyWith to use the factory constructor ---
  Transaction copyWith({
    int? id,
    String? uuid,
    String? title,
    double? amount,
    String? description,
    DateTime? date,
    int? categoryId,
    int? fromAccountId,
    int? toAccountId,
    bool? setToAccountIdNull, // Helper to explicitly nullify toAccount
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    Map<String, dynamic>? metadata,
    DateTime? deletedAt,
    bool? setDeletedAtNull,
  }) {
    // Determine the final IDs based on parameters and existing targetIds
    int? finalToAccountId;
    if (setToAccountIdNull == true) {
      finalToAccountId = null;
    } else {
      // Prioritize explicit ID, then existing targetId
      finalToAccountId = toAccountId ?? this.toAccount.targetId;
      if (finalToAccountId == 0) finalToAccountId = null; // Treat 0 as null
    }

    // Prioritize explicit ID, then existing targetId
    final finalCategoryId = categoryId ?? this.category.targetId;
    final finalFromAccountId = fromAccountId ?? this.fromAccount.targetId;

    // Use the factory constructor
    return Transaction.createWithIds(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      description: description ?? this.description,
      date: date ?? this.date,
      categoryId: finalCategoryId,
      fromAccountId: finalFromAccountId,
      toAccountId: finalToAccountId,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update timestamp on copy
      userId: userId ?? this.userId,
      metadata: metadata ?? this.metadata,
      deletedAt:
          setDeletedAtNull == true ? null : (deletedAt ?? this.deletedAt),
    );
  }

  // --- Updated fromJson Factory to use the factory constructor ---
  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Helper to parse dates safely
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value as String)?.toLocal();

    // Parse IDs directly from JSON
    final categoryIdFromJson = (json['category_id'] as num?)?.toInt() ??
        Defaults().defaultCategory.id; // Fallback ID
    final fromAccountIdFromJson = (json['from_account_id'] as num?)?.toInt() ??
        Defaults().defaultAccount.id; // Fallback ID
    final toAccountIdFromJson =
        (json['to_account_id'] as num?)?.toInt(); // Nullable

    // Use the factory constructor
    return Transaction.createWithIds(
      id: (json['id'] as num?)?.toInt() ?? 0,
      uuid: json['uuid'] as String?,
      title: json['title'] as String? ?? 'Unknown Title',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      date: parseDate(json['date']) ?? DateTime.now(),
      categoryId: categoryIdFromJson,
      fromAccountId: fromAccountIdFromJson,
      toAccountId: toAccountIdFromJson,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      userId: json['user_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      deletedAt: parseDate(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'uuid': uuid,
      'title': title,
      'description': description,
      'amount': amount,
      'category_id': category.targetId == 0 ? null : category.targetId,
      'from_account_id':
          fromAccount.targetId == 0 ? null : fromAccount.targetId,
      'to_account_id': toAccount.targetId == 0 ? null : toAccount.targetId,
      'date': date.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': userId,
      'metadata': metadata,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  @override
  List<Object?> get props => [
        id,
        uuid,
        title,
        amount,
        description,
        date,
        createdAt,
        updatedAt,
        userId,
        metadata,
        deletedAt,
        category.targetId,
        fromAccount.targetId,
        toAccount.targetId,
      ];

  @override
  String toString() {
    return 'Transaction{id: $id, uuid: $uuid, title: $title, amount: $amount, date: $date, '
        'catId: ${category.targetId}, fromAccId: ${fromAccount.targetId}, toAccId: ${toAccount.targetId}, '
        'userId: $userId, deletedAt: $deletedAt}';
  }
}
