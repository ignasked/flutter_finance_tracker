import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';

@Entity()

/// Represents a financial transaction with details such as title, amount, type (income/expense), category, and date.
// ignore: must_be_immutable
class Transaction extends Equatable {
  @Id()
  int id;
  final String title;
  final double amount;
  final bool isIncome;
  final String category;
  final DateTime date;

  Transaction(
      {this.id = 0,
      required this.title,
      required this.amount,
      required this.isIncome,
      required this.category,
      required this.date});

  @override
  List<Object?> get props => [id, title, amount, isIncome, category, date];

  /// Creates a copy of this transaction with updated fields.
  Transaction copyWith({
    int? id,
    String? title,
    double? amount,
    bool? isIncome,
    String? category,
    DateTime? date,
  }) {
    return Transaction(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      isIncome: isIncome ?? this.isIncome,
      category: category ?? this.category,
      date: date ?? this.date,
    );
  }

  static String toCSVHeader() {
    return 'id,title,amount,isIncome,category,date';
  }

  String toCSV() {
    return '$id,$title,$amount,$isIncome,$category,$date';
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
      isIncome: fields[3].toLowerCase() == 'true',
      category: fields[4],
      date: DateTime.parse(fields[5]),
    );
  }

  // Factory method to create a Transaction from JSON
  factory Transaction.fromJson(Map<String, dynamic> json) {
    return Transaction(
      title: json['title'] ?? 'Unknown Item',
      category: json['category'] ?? 'other',
      amount: (json['amount'] ?? 0.0).toDouble(),
      isIncome:
          json['isIncome'] ?? true, // Assuming all transactions are expenses
      date: json['date'] != null
          ? DateTime.tryParse(json['date']) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  // Convert a Transaction object to a JSON-compatible map
  Map<String, dynamic> toJson() {
    return {
      'title': title,
      'category': category,
      'amount': amount,
      'isIncome': isIncome,
      'date': date.toIso8601String(),
    };
  }
}
