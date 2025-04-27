import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';
import 'transaction.dart';
import 'package:money_owl/utils/enums.dart';

@Entity()
// ignore: must_be_immutable
class Account extends Equatable {
  @Id()
  int id;

  final String name;
  final int iconCodePoint; // IconData code point
  final int colorValue; // Color value as an integer
  final double balance; // Optional: Current balance of the account
  final bool isEnabled;
  final bool excludeFromTotalBalance; // Exclude from total balance calculation

  @Property(type: PropertyType.int)
  final int typeValue; // Store AccountType as an int

  @Backlink('account')
  final ToMany<Transaction> transactions = ToMany<Transaction>();

  // Getter to convert the stored integer back to the enum
  AccountType get type => AccountType.values[typeValue];

  // Constructor
  Account({
    this.id = 0,
    required this.name,
    required this.iconCodePoint,
    required this.colorValue,
    required this.typeValue, // Pass AccountType as an int
    this.balance = 0.0,
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
      'iconCodePoint': iconCodePoint,
      'colorValue': colorValue,
      'balance': balance,
      'isEnabled': isEnabled,
      'excludeFromTotalBalance': excludeFromTotalBalance,
      'type': type.toString().split('.').last, // Save enum as string
    };
  }

  // Create an Account from JSON
  factory Account.fromJson(Map<String, dynamic> json) {
    return Account(
      id: json['id'] ?? 0,
      name: json['name'],
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
