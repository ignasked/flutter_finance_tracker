import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
// ignore: must_be_immutable
class Category extends Equatable {
  @Id()
  int id; // ObjectBox requires an ID field for persistence

  final String title;
  final String descriptionForAI; // Description for AI interpretation
  final int iconCodePoint; // Store IconData as an int
  final int typeValue; // Store TransactionType as an int
  final bool isEnabled; // To allow enabling/disabling categories
  final int colorValue; // Store Color as an int

  // Add userId field
  final String? userId;

  @Property(type: PropertyType.date)
  final DateTime createdAt;

  @Property(type: PropertyType.date)
  final DateTime updatedAt;

  @Backlink('category')
  final ToMany<Transaction> transactions = ToMany<Transaction>();

  TransactionType get type => TransactionType.values[typeValue]; // Getter
  Color get color => Color(colorValue); // Getter
  IconData get icon =>
      IconData(iconCodePoint, fontFamily: 'MaterialIcons'); // Getter

  Category({
    this.id = 0, // Default ID for ObjectBox (auto-incremented)
    required this.title,
    required this.descriptionForAI,
    required this.colorValue, // Pass color as int
    required this.iconCodePoint, // Pass icon as int
    required this.typeValue, // Pass TransactionType as int
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId, // Add userId parameter
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  // Convert to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id == 0 ? null : id,
      'title': title,
      'description_for_ai':
          descriptionForAI, // Use snake_case for Supabase columns
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
      'type': type.toString().split('.').last, // Store enum as string
      'is_enabled': isEnabled,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'user_id': userId, // Include userId in JSON
    };
  }

  // Create a Category from Supabase JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] as int,
      title: json['title'] as String,
      descriptionForAI: json['description_for_ai'] as String,
      colorValue: json['color_value'] as int,
      iconCodePoint: json['icon_code_point'] as int,
      typeValue: TransactionType.values
          .firstWhere(
            (e) => e.toString().split('.').last == (json['type'] as String),
          )
          .index,
      isEnabled: json['is_enabled'] as bool? ?? true,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      userId: json['user_id'] as String?, // Read userId from JSON
    );
  }

  // Add copyWith method
  Category copyWith({
    int? id,
    String? title,
    String? descriptionForAI,
    int? colorValue,
    int? iconCodePoint,
    int? typeValue,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId, // Add userId parameter
  }) {
    return Category(
      id: id ?? this.id,
      title: title ?? this.title,
      descriptionForAI: descriptionForAI ?? this.descriptionForAI,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      typeValue: typeValue ?? this.typeValue,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Update timestamp on copy
      userId: userId ?? this.userId, // Copy userId
    );
  }

  @override
  List<Object?> get props => [
        id,
        title,
        descriptionForAI,
        colorValue,
        iconCodePoint,
        typeValue,
        isEnabled,
        createdAt,
        updatedAt,
        userId, // Add userId to props
      ];

  // Keep custom == and hashCode if needed, otherwise Equatable handles it
  // @override
  // bool operator ==(Object other) { ... }

  // @override
  // int get hashCode { ... }
}
