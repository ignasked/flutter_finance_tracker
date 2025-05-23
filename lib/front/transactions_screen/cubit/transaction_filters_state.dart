import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';

class TransactionFiltersState extends Equatable {
  final Account? selectedAccount;
  final List<Category> selectedCategories;
  final DateTime? startDate; // For date range filter
  final DateTime? endDate; // For date range filter
  final double? minAmount;
  final bool? isIncome;

  const TransactionFiltersState({
    this.selectedAccount,
    this.selectedCategories = const [],
    this.startDate,
    this.endDate,
    this.minAmount,
    this.isIncome,
  });

  TransactionFiltersState copyWith({
    Account? selectedAccount,
    bool resetSelectedAccount = false,
    List<Category>? selectedCategories,
    bool singleDay = false,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    bool? isIncome,
  }) {
    return TransactionFiltersState(
      selectedAccount: selectedAccount ??
          (resetSelectedAccount ? null : this.selectedAccount),
      selectedCategories: selectedCategories ?? this.selectedCategories,
      startDate: startDate ?? this.startDate,
      endDate: singleDay ? null : endDate ?? this.endDate,
      minAmount: minAmount ?? this.minAmount,
      isIncome: isIncome ?? this.isIncome,
    );
  }

  @override
  List<Object?> get props => [
        selectedAccount,
        selectedCategories,
        startDate,
        endDate,
        minAmount,
        isIncome,
      ];
}
