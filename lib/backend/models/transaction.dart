import 'package:equatable/equatable.dart';
import 'package:money_owl/utils/enums.dart';
import 'package:objectbox/objectbox.dart';
import 'category.dart'; // Import the Category model

@Entity()

/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
// ignore: must_be_immutable
class Transaction extends Equatable {
  @Id()
  int id;
  final String title;
  final double amount;

  // Define a relation to the Category model
  final ToOne<Category> category = ToOne<Category>();

  @Property(type: PropertyType.date)
  final DateTime date;

  Transaction({
    this.id = 0,
    required this.title,
    required this.amount,
    required this.date,
    Category? category,
  }) {
    if (category != null) {
      this.category.target = category;
    }
  }

  /// Getter to determine if the transaction is income or expense based on the category
  bool get isIncome {
    return category.target?.type == TransactionType.income;
  }

  @override
  List<Object?> get props =>
      [id, title, amount, isIncome, category.target, date];

  /// Creates a copy of this transaction with updated fields.
  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    Category? category,
    DateTime? date,
  }) {
    final updatedTransaction = Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      date: date ?? this.date,
    );
    updatedTransaction.category.target = category ?? this.category.target;
    return updatedTransaction;
  }

  static String toCSVHeader() {
    return 'id,title,amount,isIncome,category,date';
  }

  String toCSV() {
    return '$id,$title,$amount,$isIncome,${category.target?.id},$date';
  }

  static Transaction fromCSV(String csv) {
    List<String> fields = csv.split(',');
    if (fields.length != 6) {
      throw Exception('Invalid CSV format');
    }
    // Parse the fields and create a Transaction object
    return Transaction(
      id: int.parse(fields[0]),
      title: fields[1],
      amount: double.parse(fields[2]),
      date: DateTime.parse(fields[5]),
      category: null, // TODO: Implement proper Category parsing from CSV
    );
  }

  // Factory method to create a Transaction from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      id: json['id'] ?? 0,
      title: json['title'] ?? 'Unknown',
      amount: (json['amount'] ?? 0.0).toDouble(),
      date: DateTime.parse(json['date']),
    )..category.targetId = json['categoryId'];
  }

  // Convert a Transaction object to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'amount': amount,
      'isIncome': isIncome, // Derived from the category
      'categoryId': category.targetId, // Save the category ID
      'date': date.toIso8601String(),
    };
  }
}
