import 'package:bloc/bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/front/transactions_screen/cubit/date_cubit.dart'; // Import DateCubit
import 'dart:async'; // Import for StreamSubscription
import 'package:money_owl/shared/filter_utils.dart'; // Import the utility function

import 'filter_state.dart';

class FilterCubit extends Cubit<FilterState> {
  late final StreamSubscription<DateState> _dateSubscription;
  final DateCubit _dateCubit; // Keep DateCubit for date UI changes

  FilterCubit(this._dateCubit) : super(const FilterState()) {
    // Initialize with DateCubit's initial state
    _updateDateFromDateCubit(_dateCubit.state);

    // Listen to DateCubit changes
    _dateSubscription = _dateCubit.stream.listen(_updateDateFromDateCubit);
  }

  // Helper method to update filter state based on DateCubit state
  void _updateDateFromDateCubit(DateState dateState) {
    if (dateState.selectedEndDate == null) {
      // Single day selected
      emit(state.copyWith(
        startDate: dateState.selectedStartDate,
        singleDay: true,
      ));
    } else {
      // Date range selected
      emit(state.copyWith(
        startDate: dateState.selectedStartDate,
        endDate: dateState.selectedEndDate,
        singleDay: false,
      ));
    }
  }

  void changeSelectedAccount(Account? account) {
    if (account == null) {
      emit(state.copyWith(resetSelectedAccount: true));
    } else {
      emit(state.copyWith(selectedAccount: account));
    }
  }

  void changeSelectedCategories(List<Category> categories) {
    emit(state.copyWith(selectedCategories: categories));
  }

  // Note: Date changes are now driven by listening to DateCubit
  // void changeDateRange(DateTime? startDate, DateTime? endDate) {
  //   emit(state.copyWith(startDate: startDate, endDate: endDate, singleDay: false));
  // }

  // void changeSingleDay(DateTime? singleDay) {
  //   emit(state.copyWith(startDate: singleDay, singleDay: true));
  // }

  void changeMinAmount(double? minAmount) {
    emit(state.copyWith(minAmount: minAmount));
  }

  void changeIsIncome(bool? isIncome) {
    emit(state.copyWith(isIncome: isIncome));
  }

  void resetFilters() {
    // Reset filters in FilterCubit state, keep date filters
    emit(state.resetFilters());
    // Also reset DateCubit to its default/initial state if needed
    // _dateCubit.resetDates(); // Assuming DateCubit has a reset method
  }

  @override
  Future<void> close() {
    _dateSubscription.cancel(); // Cancel subscription
    return super.close();
  }
}
