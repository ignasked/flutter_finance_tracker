import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';
import 'package:uuid/uuid.dart';
import 'transaction.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:flutter/material.dart';

@Entity()
// ignore: must_be_immutable
class Account extends Equatable {
  @Id()
  int id;

  @Index() // Index UUID for faster lookups during sync
  @Unique(onConflict: ConflictStrategy.replace) // Ensure UUID is unique locally
  String uuid; // Globally unique identifier

  final String name;
  final String currency;
  final String? currencySymbol;
  @Transient()
  double balance;
  @Property(type: PropertyType.int)
  final int typeValue; // Stores AccountType as int
  final int colorValue; // Stores color as int
  final int iconCodePoint; // Stores icon as int
  final bool isEnabled; // Track if the account is active

  @Property(type: PropertyType.date)
  final DateTime createdAt;

  @Property(type: PropertyType.date)
  DateTime updatedAt;

  @Index() // Index for faster lookups by userId
  final String? userId;

  @Property(type: PropertyType.date)
  @Index()
  DateTime? deletedAt; // Nullable: Tracks deletion time (UTC)

  // Backlink to transactions where this account is the 'fromAccount'
  @Backlink('fromAccount')
  final ToMany<Transaction> transactionsFrom = ToMany<Transaction>();

  // Backlink to transactions where this account is the 'toAccount'
  @Backlink('toAccount')
  final ToMany<Transaction> transactionsTo = ToMany<Transaction>();

  AccountType get type => AccountType.values[typeValue];
  Color get color => Color(colorValue);
  IconData get icon => IconData(iconCodePoint, fontFamily: 'MaterialIcons');
  bool get isDeleted => deletedAt != null;
  String get currencySymbolOrCurrency => currencySymbol ?? currency;

  Account({
    this.id = 0, // ObjectBox will assign an ID if 0
    String? uuid, // Accept optional UUID (e.g., from sync)
    required this.name,
    required this.currency,
    this.currencySymbol,
    this.balance = 0.0,
    required this.typeValue,
    required this.colorValue,
    required this.iconCodePoint,
    this.isEnabled = true,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId,
    this.deletedAt, // Allow setting deletedAt on creation
  })  : uuid = uuid ?? const Uuid().v4(), // Generate UUID if not provided
        createdAt = createdAt ?? DateTime.now().toUtc(),
        updatedAt = updatedAt ?? DateTime.now().toUtc();

  @override
  List<Object?> get props => [
        id,
        uuid,
        name,
        currency,
        currencySymbol,
        balance,
        typeValue,
        colorValue,
        iconCodePoint,
        isEnabled,
        createdAt,
        updatedAt,
        userId,
        deletedAt,
      ];

  Account copyWith({
    int? id,
    String? uuid,
    String? name,
    String? currency,
    String? currencySymbol,
    double? balance,
    int? typeValue,
    int? colorValue,
    int? iconCodePoint,
    bool? isEnabled,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId,
    DateTime? deletedAt,
    bool? setDeletedAtNull,
  }) {
    return Account(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      currencySymbol: currencySymbol ?? this.currencySymbol,
      balance: balance ?? this.balance,
      typeValue: typeValue ?? this.typeValue,
      colorValue: colorValue ?? this.colorValue,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      isEnabled: isEnabled ?? this.isEnabled,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      userId: userId ?? this.userId,
      deletedAt:
          setDeletedAtNull == true ? null : (deletedAt ?? this.deletedAt),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id == 0 ? null : id,
      'uuid': uuid,
      'name': name,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'balance': balance,
      'type_value': typeValue,
      'color_value': colorValue,
      'icon_code_point': iconCodePoint,
      'is_enabled': isEnabled,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': DateTime.now().toUtc().toIso8601String(),
      'user_id': userId,
      'deleted_at': deletedAt?.toUtc().toIso8601String(),
    };
  }

  factory Account.fromJson(Map<String, dynamic> json) {
    DateTime? parseDate(dynamic value) =>
        value == null ? null : DateTime.tryParse(value as String)?.toLocal();

    return Account(
      id: (json['id'] as num?)?.toInt() ??
          0, // Use ID from Supabase if available
      uuid: json['uuid'] as String?,
      name: json['name'] as String? ?? 'Unknown Account',
      currency: json['currency'] as String? ?? 'USD',
      currencySymbol: json['currency_symbol'] as String?,
      balance: (json['balance'] as num?)?.toDouble() ?? 0.0,
      typeValue:
          (json['type_value'] as num?)?.toInt() ?? AccountType.bank.index,
      colorValue: (json['color_value'] as num?)?.toInt() ?? Colors.grey.value,
      iconCodePoint: (json['icon_code_point'] as num?)?.toInt() ??
          Icons.question_mark.codePoint,
      isEnabled: json['is_enabled'] as bool? ?? true,
      createdAt: parseDate(json['created_at']),
      updatedAt: parseDate(json['updated_at']),
      userId: json['user_id'] as String?,
      deletedAt: parseDate(json['deleted_at']),
    );
  }

  @override
  String toString() {
    return 'Account{id: $id, uuid: $uuid, name: $name, balance: $balance $currency, userId: $userId, deletedAt: $deletedAt}';
  }
}
