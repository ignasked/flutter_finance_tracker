import 'package:equatable/equatable.dart';
// Remove unused import
import 'package:objectbox/objectbox.dart';
import 'transaction.dart';
import 'package:money_owl/backend/utils/enums.dart';

@Entity()
// ignore: must_be_immutable
class Account extends Equatable {
  @Id()
  int id;

  final String name;
  final String currency;
  final String? currencySymbol;
  final double balance; // Optional: Current balance of the account
  @Property(type: PropertyType.int)
  final int typeValue; // Store AccountType as an int

  // Update the Backlink to point to 'fromAccount' in Transaction model
  @Backlink('fromAccount')
  final ToMany<Transaction> transactionsFrom = ToMany<Transaction>();

  @Backlink('toAccount')
  final ToMany<Transaction> transactionsTo = ToMany<Transaction>();

// Visual representation of the account
  final int iconCodePoint; // IconData code point
  final int colorValue; // Color value as an integer
  final bool isEnabled; // Is the account enabled or archived.
  final bool excludeFromTotalBalance; // Exclude from total balance calculation

  @Property(type: PropertyType.date) // Store as millisecond timestamp
  final DateTime createdAt;

  @Property(type: PropertyType.date) // Store as millisecond timestamp
  final DateTime updatedAt;

  // Add userId field
  final String? userId;

  // Getter to convert the stored integer back to the enum
  AccountType get type => AccountType.values[typeValue];
  String get currencySymbolOrCurrency {
    return currencySymbol ?? currency;
  }

  // Constructor
  Account({
    this.id = 0,
    required this.name,
    required this.typeValue, // Pass AccountType as an int
    required this.currency,
    this.currencySymbol,
    this.balance = 0.0,
    required this.iconCodePoint,
    required this.colorValue,
    this.isEnabled = true,
    this.excludeFromTotalBalance = false,
    DateTime? createdAt,
    DateTime? updatedAt,
    this.userId, // Add userId parameter
  })  : assert(
          typeValue >= 0 && typeValue < AccountType.values.length,
          'Invalid AccountType value: $typeValue',
        ),
        this.createdAt = createdAt ?? DateTime.now(),
        this.updatedAt = updatedAt ?? (createdAt ?? DateTime.now());

  // Convert to JSON for saving preferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'currency_symbol': currencySymbol,
      'type_value': typeValue,
      'balance': balance,
      'type': type.toString().split('.').last, // Save enum as string
      'icon_code_point': iconCodePoint,
      'color_value': colorValue,
      'is_enabled': isEnabled,
      'exclude_from_total_balance': excludeFromTotalBalance,
      'created_at': createdAt.toUtc().toIso8601String(),
      'updated_at': updatedAt.toUtc().toIso8601String(),
      'user_id': userId, // Include userId in JSON
    };
  }

  // Create an Account from JSON
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? 0,
      name: json['name'],
      currency: json['currency'] ?? 'USD',
      currencySymbol: json['currency_symbol'] ?? '\$',
      iconCodePoint: json['icon_code_point'] ?? 0,
      colorValue: json['color_value'],
      typeValue: AccountType.values
          .firstWhere(
            (e) => e.toString().split('.').last == json['type'],
          )
          .index, // Convert string back to enum index
      balance: json['balance'] ?? 0.0,
      isEnabled: json['is_enabled'] ?? true,
      excludeFromTotalBalance: json['exclude_from_total_balance'] ?? false,
      createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
      updatedAt: DateTime.parse(json['updated_at'] as String).toLocal(),
      userId: json['user_id'] as String?, // Read userId from JSON
    );
  }

  // Add copyWith method
  Account copyWith({
    int? id,
    String? name,
    String? currency,
    int? iconCodePoint,
    int? colorValue,
    int? typeValue,
    double? balance,
    bool? isEnabled,
    bool? excludeFromTotalBalance,
    DateTime? createdAt,
    DateTime? updatedAt,
    String? userId, // Add userId parameter
  }) {
    return Account(
      id: id ?? this.id,
      name: name ?? this.name,
      currency: currency ?? this.currency,
      iconCodePoint: iconCodePoint ?? this.iconCodePoint,
      colorValue: colorValue ?? this.colorValue,
      typeValue: typeValue ?? this.typeValue,
      balance: balance ?? this.balance,
      isEnabled: isEnabled ?? this.isEnabled,
      excludeFromTotalBalance:
          excludeFromTotalBalance ?? this.excludeFromTotalBalance,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? DateTime.now(),
      userId: userId ?? this.userId, // Copy userId
    );
  }

  @override
  List<Object?> get props => [
        id,
        name,
        iconCodePoint,
        colorValue,
        iconCodePoint,
        typeValue,
        balance,
        isEnabled,
        excludeFromTotalBalance,
        createdAt,
        updatedAt,
        userId, // Add userId to props
      ];
}
