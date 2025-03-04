import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
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
}
