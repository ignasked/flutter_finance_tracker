import 'package:objectbox/objectbox.dart';

@Entity()
class Transaction {
  @Id()
  int id = 0;
  String title;
  double amount;
  bool isIncome;
  String category;
  DateTime date;

  Transaction({this.id = 0, required this.title, required this.amount, required this.isIncome, required this.category, required this.date});
}