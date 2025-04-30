import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/utils/defaults.dart';
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
  @Backlink('account')
  final ToMany<Transaction> transactions = ToMany<Transaction>();

// Visual representation of the account
  final int iconCodePoint; // IconData code point
  final int colorValue; // Color value as an integer
  final bool isEnabled; // Is the account enabled or archived.
  final bool excludeFromTotalBalance; // Exclude from total balance calculation

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
  }) : assert(
          typeValue >= 0 && typeValue < AccountType.values.length,
          'Invalid AccountType value: $typeValue',
        );

  // Convert to JSON for saving preferences
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'currency': currency,
      'typeValue': typeValue,
      'balance': balance,
      'type': type.toString().split('.').last, // Save enum as string
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'isEnabled': isEnabled,
      'excludeFromTotalBalance': excludeFromTotalBalance,
    };
  }

  // Create an Account from JSON
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? 0,
      name: json['name'],
      currency: json['currency'] ?? 'USD',

      iconCodePoint: json['iconCodePoint'],
      colorValue: json['colorValue'],
      typeValue: AccountType.values
          .firstWhere(
            (e) => e.toString().split('.').last == json['type'],
          )
          .index, // Convert string back to enum index
      balance: json['balance'] ?? 0.0,
      isEnabled: json['isEnabled'] ?? true,
      excludeFromTotalBalance: json['excludeFromTotalBalance'] ?? false,
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
      ];
}
