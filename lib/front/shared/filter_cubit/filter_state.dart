import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';

class FilterState extends Equatable {
  final Account? selectedAccount;
  final List<Category> selectedCategories;
  final DateTime? startDate;
  final DateTime? endDate;
  final double? minAmount;
  final bool? isIncome; // true for income, false for expense, null for both
  final bool singleDay; // Indicates if only a single day is selected

  const FilterState({
    this.selectedAccount,
    this.selectedCategories = const [],
    this.startDate,
    this.endDate,
    this.minAmount,
    this.isIncome,
    this.singleDay = false, // Default to false (range selection)
  });

  // Helper to check if any filters are active besides date
  bool get hasActiveFilters {
    return selectedAccount != null ||
        selectedCategories.isNotEmpty ||
        minAmount != null ||
        isIncome != null;
  }

  FilterState copyWith({
    Account? selectedAccount,
    bool resetSelectedAccount = false, // Flag to explicitly set account to null
    List<Category>? selectedCategories,
    DateTime? startDate,
    DateTime? endDate,
    double? minAmount,
    bool? isIncome,
    bool? singleDay,
  }) {
    return FilterState(
      selectedAccount:
          resetSelectedAccount ? null : selectedAccount ?? this.selectedAccount,
      selectedCategories: selectedCategories ?? this.selectedCategories,
      startDate: startDate ?? this.startDate,
      endDate: singleDay == true
          ? null
          : (endDate ?? this.endDate), // Clear endDate if singleDay is true
      minAmount: minAmount ?? this.minAmount,
      isIncome: isIncome ?? this.isIncome,
      singleDay: singleDay ?? this.singleDay,
    );
  }

  // Method to reset all filters except date
  FilterState resetFilters() {
    return FilterState(
      startDate: startDate, // Keep existing date filters
      endDate: endDate,
      singleDay: singleDay,
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
        singleDay,
      ];
}
