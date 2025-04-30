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
  });

  // Convert to JSON for saving preferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'descriptionForAI': descriptionForAI,
      'colorValue': colorValue,
      'iconCodePoint': iconCodePoint,
      'type': type.toString().split('.').last,
      'isEnabled': isEnabled,
    };
  }

  // Create a Category from JSON
  factory Category.fromJson(Map<String, dynamic> json) {
    return Category(
      id: json['id'] ?? 0,
      title: json['title'],
      descriptionForAI: json['descriptionForAI'],
      colorValue: json['colorValue'], // Pass color as int
      iconCodePoint: json['iconCodePoint'], // Pass icon as int
      typeValue: TransactionType.values
          .firstWhere(
            (e) => e.toString().split('.').last == json['type'],
          )
          .index, // Pass TransactionType as int
      isEnabled: json['isEnabled'] ?? true,
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
  }) {
    return Category(
      id: id ?? this.id,
      title: title ?? this.title,
      descriptionForAI: descriptionForAI ?? this.descriptionForAI,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      typeValue: typeValue ?? this.typeValue,
      isEnabled: isEnabled ?? this.isEnabled,
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
      ];

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;

    return other is Category &&
        other.id == id &&
        other.title == title &&
        other.descriptionForAI == descriptionForAI &&
        other.colorValue == colorValue &&
        other.iconCodePoint == iconCodePoint &&
        other.typeValue == typeValue &&
        other.isEnabled == isEnabled;
  }

  @override
  int get hashCode {
    return id.hashCode ^
        title.hashCode ^
        descriptionForAI.hashCode ^
        colorValue.hashCode ^
        iconCodePoint.hashCode ^
        typeValue.hashCode ^
        isEnabled.hashCode;
  }
}
