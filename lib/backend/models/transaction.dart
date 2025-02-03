import 'package:equatable/equatable.dart';
import 'package:objectbox/objectbox.dart';

@Entity()
class Transaction extends Equatable {
  @Id()
  int id = 0;
  String title;
  double amount;
  bool isIncome;
  String category;
  DateTime date;

  Transaction({this.id = 0, required this.title, required this.amount, required this.isIncome, required this.category, required this.date});

  @override
  // TODO: implement props
  List<Object?> get props => [id, title, amount, isIncome, category, date];

}