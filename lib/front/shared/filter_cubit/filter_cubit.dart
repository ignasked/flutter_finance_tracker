import 'package:bloc/bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/front/shared/data_management_cubit/date_cubit.dart';
import 'dart:async'; // For StreamSubscription

import 'filter_state.dart';

class FilterCubit extends Cubit<FilterState> {
  late final StreamSubscription<DateState> _dateSubscription;
  final DateCubit _dateCubit; // Holds DateCubit to listen for date UI changes.

  FilterCubit(this._dateCubit) : super(const FilterState()) {
    // Initialize filter state with DateCubit's current state.
    _updateDateFromDateCubit(_dateCubit.state);

    // Listen to DateCubit changes to update the filter accordingly.
    _dateSubscription = _dateCubit.stream.listen(_updateDateFromDateCubit);
  }

  // Updates the filter state based on changes from DateCubit.
  void _updateDateFromDateCubit(DateState dateState) {
    if (dateState.selectedEndDate == null) {
      // Single day selected.
      emit(state.copyWith(
        startDate: dateState.selectedStartDate,
        singleDay: true,
      ));
    } else {
      // Date range selected.
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

  void changeMinAmount(double? minAmount) {
    emit(state.copyWith(minAmount: minAmount));
  }

  void changeIsIncome(bool? isIncome) {
    emit(state.copyWith(isIncome: isIncome));
  }

  void resetFilters() {
    // Reset filters in FilterCubit state while retaining date filters.
    emit(state.resetFilters());
    _dateCubit.resetDate(); // Assuming DateCubit has a reset method.
  }

  @override
  Future<void> close() {
    _dateSubscription.cancel(); // Cancel subscription.
    return super.close();
  }
}
