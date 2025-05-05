import 'package:bloc/bloc.dart';
import 'package:money_owl/backend/utils/defaults.dart';

class DateState {
  final DateTime selectedStartDate;
  final DateTime? selectedEndDate;

  const DateState({
    required this.selectedStartDate,
    this.selectedEndDate,
  });

  DateState copyWith({
    DateTime? selectedStartDate,
    DateTime? selectedEndDate,
    bool singleDay = false,
  }) {
    return DateState(
      selectedStartDate: selectedStartDate ?? this.selectedStartDate,
      selectedEndDate:
          singleDay ? null : selectedEndDate ?? this.selectedEndDate,
    );
  }
}

class DateCubit extends Cubit<DateState> {
  DateCubit()
      : super(DateState(
          selectedStartDate: Defaults().defaultDateRangeStart,
          selectedEndDate: Defaults().defaultDateRangeEnd,
        ));

  void moveToPrevious() {
    if (state.selectedEndDate == null) {
      // Move to the previous day
      emit(state.copyWith(
        selectedStartDate:
            state.selectedStartDate.subtract(const Duration(days: 1)),
      ));
    } else {
      // Move the range back by its length
      final rangeLength =
          state.selectedEndDate!.difference(state.selectedStartDate).inDays + 1;
      emit(state.copyWith(
        selectedStartDate:
            state.selectedStartDate.subtract(Duration(days: rangeLength)),
        selectedEndDate:
            state.selectedEndDate!.subtract(Duration(days: rangeLength)),
      ));
    }
  }

  void moveToNext() {
    if (state.selectedEndDate == null) {
      // Move to the next day
      emit(state.copyWith(
        selectedStartDate: state.selectedStartDate.add(const Duration(days: 1)),
      ));
    } else {
      // Move the range forward by its length
      final rangeLength =
          state.selectedEndDate!.difference(state.selectedStartDate).inDays + 1;
      emit(state.copyWith(
        selectedStartDate:
            state.selectedStartDate.add(Duration(days: rangeLength)),
        selectedEndDate:
            state.selectedEndDate!.add(Duration(days: rangeLength)),
      ));
    }
  }

  void selectDateRange(DateTime startDate, DateTime? endDate, bool singleDay) {
    if (singleDay) {
      endDate = null;
    } else if (endDate != null) {
      // If the end date is not null, ensure it is after the start date
      if (endDate.isBefore(startDate)) {
        endDate = startDate;
      }
    }
    emit(state.copyWith(
      selectedStartDate: startDate,
      selectedEndDate: endDate,
      singleDay: singleDay,
    ));
  }

  void resetDate() {
    emit(DateState(
      selectedStartDate: Defaults().defaultDateRangeStart,
      selectedEndDate: Defaults().defaultDateRangeEnd,
    ));
  }
}
