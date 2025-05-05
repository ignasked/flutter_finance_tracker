import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';

@Entity()
// ignore: must_be_immutable
class Category extends Equatable {
  @Id()
  int id; // ObjectBox requires an ID field for persistence

  @Index() // Index UUID for faster lookups during sync
  @Unique(onConflict: ConflictStrategy.replace) // Ensure UUID is unique locally
  String uuid; //

  final String title;
  final String? descriptionForAI; // Description for AI interpretation
  final int iconCodePoint; // Store IconData as an int
  final int typeValue; // Store TransactionType as an int
  final bool isEnabled; // To allow enabling/disabling categories
  final int colorValue; // Store Color as an int

  @Index() // Index userId
  final String? userId;

  @Property(type: PropertyType.date)
  final DateTime createdAt;
  @Property(type: PropertyType.date)
  final DateTime updatedAt;
  @Property(type: PropertyType.date)
  final DateTime? deletedAt; // Nullable: Tracks deletion time (UTC)

  @Backlink('category')
  final ToMany<Transaction> transactions = ToMany<Transaction>();

  TransactionType get type => TransactionType.values[typeValue]; // Getter
  Color get color => Color(colorValue); // Getter
  IconData get icon =>
      IconData(iconCodePoint, fontFamily: 'MaterialIcons'); // Getter
  bool get isDeleted => deletedAt != null; // Helper getter

  Category({
    this.id = 0, // ObjectBox will assign if 0
    String? uuid, // Accept optional UUID
    required this.title,
    this.descriptionForAI,
    required this.colorValue,
    required this.iconCodePoint,
    required this.typeValue,
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.deletedAt,
  })  : uuid = uuid ?? const Uuid().v4(), // Generate UUID if not provided
        createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() => {
        'id': id == 0
            ? null
            : id, // Send ID (null if 0, though should have ID when syncing up existing)
        'uuid': uuid,
        'title': title,
        'description_for_ai': descriptionForAI,
        'icon_code_point': iconCodePoint,
        'type_value': typeValue,
        'is_enabled': isEnabled,
        'color_value': colorValue,
        'created_at': createdAt.toUtc().toIso8601String(),
        'updated_at':
            DateTime.now().toUtc().toIso8601String(), // Send current UTC time
        'user_id': userId,
        'deleted_at': deletedAt?.toUtc().toIso8601String(),
      };

  // Create a Category from Supabase JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value as String)?.toLocal();

    return Category(
      id: (json['id'] as num?)?.toInt() ??
          0, // Use ID from Supabase if available
      uuid: json['uuid'] as String?, // Get UUID from Supabase
      title: json['title'] as String? ?? 'Unknown Category',
      descriptionForAI: json['description_for_ai'] as String?,
      iconCodePoint:
          (json['icon_code_point'] as num?)?.toInt() ?? Icons.error.codePoint,
      typeValue: (json['type_value'] as num?)?.toInt() ?? 0,
      isEnabled: json['is_enabled'] as bool? ?? true,
      colorValue: (json['color_value'] as num?)?.toInt() ?? Colors.grey.value,
      createdAt:
          parseDate(json['created_at']), // Let constructor handle default
      updatedAt:
          parseDate(json['updated_at']), // Let constructor handle default
      userId: json['user_id'] as String?,
      deletedAt: parseDate(json['deleted_at']),
    );
  }

  // Add copyWith method
  Category copyWith({
    int? id,
    String? uuid, // Allow copying UUID
    String? title,
    String? descriptionForAI,
    int? colorValue,
    int? iconCodePoint,
    int? typeValue,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    DateTime? deletedAt,
    bool? setDeletedAtNull,
  }) {
    return Category(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid, // Copy UUID
      title: title ?? this.title,
      descriptionForAI: descriptionForAI ?? this.descriptionForAI,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      typeValue: typeValue ?? this.typeValue,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update timestamp
      userId: userId ?? this.userId,
      deletedAt:
          setDeletedAtNull == true ? null : (deletedAt ?? this.deletedAt),
    );
  }

  @override
  List<Object?> get props => [
        id,
        uuid, // Add UUID
        title,
        descriptionForAI,
        colorValue,
        iconCodePoint,
        typeValue,
        isEnabled,
        createdAt,
        updatedAt,
        userId,
        deletedAt,
      ];

  @override
  String toString() {
    return 'Category{id: $id, uuid: $uuid, title: $title, userId: $userId, deletedAt: $deletedAt}';
  }
}
