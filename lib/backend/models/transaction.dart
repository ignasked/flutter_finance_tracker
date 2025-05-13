import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/objectbox.g.dart'; // Ensure this import exists
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart'; // Import uuid package

@Entity()

/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
// ignore: must-be-immutable
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

  DateTime updatedAt; // Mutable for easier updates

  @Index()
  String? userId;

  // --- ToOne Relations ---
  // ObjectBox links these to the targetId stored internally
  final ToOne<Category> category = ToOne<Category>();
  final ToOne<Account> fromAccount = ToOne<Account>();
  final ToOne<Account> toAccount = ToOne<Account>();

  @Transient()
  Map<String, dynamic>? metadata;

  bool get isIncome => amount > 0;
  bool get isExpense => amount < 0;
  // isTransfer uses targetId, which is an internal ObjectBox property for ToOne relations
  bool get isTransfer => toAccount.targetId != 0;

  /// Getter to determine if the transaction is deleted
  bool get isDeleted => deletedAt != null;

  // --- Main Constructor (Used by ObjectBox and app code) ---
  Transaction({
    this.id = 0, // ObjectBox will assign an ID if 0
    String? uuid, // Accept optional UUID (e.g., from sync)
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
      finalToAccountId = toAccountId ?? toAccount.targetId;
      if (finalToAccountId == 0) finalToAccountId = null; // Treat 0 as null
    }

    // Prioritize explicit ID, then existing targetId
    final finalCategoryId = categoryId ?? category.targetId;
    final finalFromAccountId = fromAccountId ?? fromAccount.targetId;

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

  // --- Updated fromJson Factory (Hybrid Approach) ---
  // Prioritizes integer IDs from JSON for local linking (compatibility).
  // Still parses UUIDs and other fields.
  factory Transaction.fromJson(Map<String, dynamic> json) {
    // Helper to parse dates safely
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value as String)?.toLocal();

    // Extract integer IDs for local linking
    final idFromJson = (json['id'] as num?)?.toInt() ?? 0;
    final categoryIdFromJson = (json['category_id'] as num?)?.toInt();
    final fromAccountIdFromJson = (json['from_account_id'] as num?)?.toInt();
    final toAccountIdFromJson = (json['to_account_id'] as num?)?.toInt();

    // Use createWithIds factory for convenience, as it handles setting targetIds.
    return Transaction.createWithIds(
      id: idFromJson, // <-- Set local ObjectBox ID from JSON
      uuid: json['uuid'] as String?, // Use UUID from JSON if available
      title: json['title'] as String? ?? 'Unknown Title',
      amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
      description: json['description'] as String?,
      date: parseDate(json['date']) ?? DateTime.now(),
      // Pass the parsed integer IDs
      categoryId: categoryIdFromJson ?? 0, // Default to 0 if null
      fromAccountId: fromAccountIdFromJson ?? 0, // Default to 0 if null
      toAccountId: toAccountIdFromJson, // Can be null
      createdAt:
          parseDate(json['created_at']), // Let constructor handle default
      updatedAt:
          parseDate(json['updated_at']), // Let constructor handle default
      userId: json['user_id'] as String?,
      metadata: json['metadata'] as Map<String, dynamic>?,
      deletedAt: parseDate(json['deleted_at']),
    );
  }

  // --- Updated toJson (Hybrid Approach) ---
  // Sends both integer IDs and UUIDs for relationships.
  Map<String, dynamic> toJson() {
    // Access the target objects to get their UUIDs
    final categoryObj = category.target;
    final fromAccountObj = fromAccount.target;
    final toAccountObj = toAccount.target;

    return {
      'id': id == 0
          ? null
          : id, // Send ID (null if 0, though should have ID when syncing up existing)-- Add this line
      'uuid': uuid,
      'title': title,
      'description': description,
      'amount': amount,
      // Send BOTH IDs and UUIDs
      'category_id': category.targetId == 0 ? null : category.targetId,
      'category_uuid': categoryObj?.uuid,
      'from_account_id':
          fromAccount.targetId == 0 ? null : fromAccount.targetId,
      'from_account_uuid': fromAccountObj?.uuid,
      'to_account_id': toAccount.targetId == 0 ? null : toAccount.targetId,
      'to_account_uuid': toAccountObj?.uuid,
      'date': date.toUtc().toIso8601String(),
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at':
          DateTime.now().toUtc().toIso8601String(), // Send current UTC time
      'user_id': userId,
      'metadata': metadata,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  Map<String, dynamic> toExportJson() {
    final categoryObj = category.target;
    final fromAccountObj = fromAccount.target;
    final toAccountObj = toAccount.target;

    return {
      ...toJson(), // All standard fields
      'category_title': categoryObj?.title,
      'from_account_name': fromAccountObj?.name,
      'to_account_name': toAccountObj?.name,
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
