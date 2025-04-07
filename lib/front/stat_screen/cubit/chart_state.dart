import 'package:equatable/equatable.dart';

class ChartState extends Equatable {
  final List<ChartData> categoryData;
  final List<LineChartData> balanceData;

  const ChartState({
    this.categoryData = const [],
    this.balanceData = const [],
  });

  @override
  List<Object> get props => [categoryData, balanceData];

  ChartState copyWith({
    List<ChartData>? categoryData,
    List<LineChartData>? balanceData,
  }) {
    return ChartState(
      categoryData: categoryData ?? this.categoryData,
      balanceData: balanceData ?? this.balanceData,
    );
  }
}

class ChartData {
  final String category;
  final double amount;

  ChartData(this.category, this.amount);
}

class LineChartData {
  final DateTime date;
  final double balance;

  LineChartData(this.date, this.balance);
}
