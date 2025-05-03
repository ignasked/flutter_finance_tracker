import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';
import 'transaction.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:flutter/material.dart';

@Entity()
// ignore: must_be_immutable
class Account extends Equatable {
  @Id()
  int id;

  final String name;
  final String currency;
  final String? currencySymbol;
  double balance; // Make balance mutable
  @Property(type: PropertyType.int)
  final int typeValue; // Store AccountType as int
  final int colorValue; // Store color as int
  final int iconCodePoint; // Store icon as int
  final bool isEnabled; // Track if the account is active

  @Property(type: PropertyType.date)
  final DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt; // Make updatedAt mutable

  @Index() // Index for faster lookups by userId
  final String? userId;

  // Add deletedAt field
  @Property(type: PropertyType.date)
  @Index()
  DateTime? deletedAt; // Nullable: Tracks deletion time (UTC)

  // Backlink to transactions where this account is the 'fromAccount'
  @Backlink('fromAccount')
  final ToMany<Transaction> transactionsFrom = ToMany<Transaction>();

  // Backlink to transactions where this account is the 'toAccount'
  @Backlink('toAccount')
  final ToMany<Transaction> transactionsTo = ToMany<Transaction>();

  // Getter for type
  AccountType get type => AccountType.values[typeValue];

  // Getter for color
  Color get color => Color(colorValue);

  // Getter for icon
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');

  // Helper getter for deletion status
  bool get isDeleted => deletedAt != null;

  // Helper getter for currency symbol or code
  String get currencySymbolOrCurrency => currencySymbol ?? currency;

  Account({
    this.id = 0,
    required this.name,
    required this.currency,
    this.currencySymbol,
    this.balance = 0.0, // Default balance to 0.0
    required this.typeValue, // Accept int
    required this.colorValue,
    required this.iconCodePoint,
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId, // Add userId parameter
    this.deletedAt, // Add deletedAt parameter
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  @override
  List<Object?> get props => [
        id,
        name,
        currency,
        currencySymbol,
        balance,
        typeValue, // Use int
        colorValue,
        iconCodePoint,
        isEnabled,
        createdAt,
        updatedAt,
        userId,
        deletedAt, // Include deletedAt in props
      ];

  Account copyWith({
    int? id,
    String? name,
    String? currency,
    String? currencySymbol,
    double? balance,
    int? typeValue, // Accept int
    int? colorValue,
    int? iconCodePoint,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    DateTime? deletedAt,
    bool? setDeletedAtNull, // Helper to explicitly set deletedAt to null
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      balance: balance ?? this.balance,
      typeValue: typeValue ?? this.typeValue, // Use int
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(), // Always update timestamp on copy
      userId: userId ?? this.userId,
      deletedAt: setDeletedAtNull == true
          ? null
          : (deletedAt ?? this.deletedAt), // Handle null setting
    );
  }

  // Convert Account to JSON for Supabase
  Map<String, dynamic> toJson() {
    return {
      'id': id == 0 ? null : id, // Let Supabase handle ID generation if 0
      'name': name,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'balance': balance,
      'type': type.toString().split('.').last, // Store enum as string
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
      'is_enabled': isEnabled,
      'created_at': createdAt.toUtc().toIso8601String(), // Store as UTC
      'updated_at': updatedAt.toUtc().toIso8601String(), // Store as UTC
      'user_id': userId,
      'deleted_at': deletedAt?.toUtc().toIso8601String(), // Store as UTC
    };
  }

  // Create Account from JSON (Supabase)
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      // Use a default ID of 0 if 'id' is null or not present
      id: json['id'] as int? ?? 0,
      name: json['name'] as String? ?? 'Unnamed Account',
      currency: json['currency'] as String? ?? 'USD',
      currencySymbol: json['currency_symbol'] as String?,
      // Provide default value for balance if null
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      // Handle potential null or invalid enum string
      typeValue: AccountType.values
          .firstWhere(
            (e) => e.toString().split('.').last == json['type'],
            orElse: () => AccountType.bank, // Default type
          )
          .index,
      // Provide default values for color and icon if null
      colorValue: json['color_value'] as int? ?? Colors.grey.value,
      iconCodePoint:
          json['icon_code_point'] as int? ?? Icons.account_balance.codePoint,
      // Provide default value for isEnabled if null
      isEnabled: json['is_enabled'] as bool? ?? true,
      // Parse dates safely, provide default if null or invalid
      createdAt: json['created_at'] != null
          ? (DateTime.tryParse(json['created_at'] as String)?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
      updatedAt: json['updated_at'] != null
          ? (DateTime.tryParse(json['updated_at'] as String)?.toLocal() ??
              DateTime.now())
          : DateTime.now(),
      userId: json['user_id'] as String?,
      // Parse deletedAt safely
      deletedAt: json['deleted_at'] != null
          ? DateTime.tryParse(json['deleted_at'] as String)?.toLocal()
          : null,
    );
  }
}
