import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/home_screen/cubit/date_cubit.dart';

/// A widget that displays a date bar with navigation buttons and a calendar button.
/// It allows users to navigate between dates and open a date selection sheet.
class DateBarWidget extends StatelessWidget {
  const DateBarWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DateCubit, DateState>(
      builder: (context, state) {
        final dateCubit = context.read<DateCubit>();
        // Format the selected date or date range

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 1.0, horizontal: 16.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(8.0),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 3,
                offset: const Offset(0, 3),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous Button
              IconButton(
                  icon: const Icon(Icons.arrow_left, color: Colors.blue),
                  onPressed: dateCubit.moveToPrevious),

              // Date Range Display
              const DateRangeDisplay(),

              // Next Button
              IconButton(
                  icon: const Icon(Icons.arrow_right, color: Colors.blue),
                  onPressed: dateCubit.moveToNext),

              // Calendar Button
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.blue),
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    shape: const RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(16)),
                    ),
                    builder: (context) => const DateSelectionOptionsSheet(),
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A widget that displays the selected date or date range in the center of the date bar.
class DateRangeDisplay extends StatelessWidget {
  const DateRangeDisplay({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DateCubit, DateState>(
      builder: (context, state) {
        return Expanded(
          child: Text(
            _formatDateRange(state.selectedStartDate, state.selectedEndDate),
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }

  /// Formats the date range for display.
  ///
  /// If [endDate] is null, only the [startDate] is displayed.
  /// Otherwise, the range is displayed as "startDate - endDate".
  String _formatDateRange(DateTime startDate, DateTime? endDate) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    if (endDate == null) {
      return dateFormat.format(startDate); // Single day
    } else {
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}'; // Date range
    }
  }
}

/// A bottom sheet widget that provides options for selecting a date filter.
///
/// Users can choose to select a single day, a month, or a date range.
class DateSelectionOptionsSheet extends StatelessWidget {
  const DateSelectionOptionsSheet({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            'Date Filter',
            style: Theme.of(context).textTheme.headlineLarge,
          ),
          const SizedBox(height: 16.0),
          const SelectDayButton(),
          const SizedBox(height: 8.0),
          const SelectMonthButton(),
          const SizedBox(height: 8.0),
          const SelectDateRangeButton(),
          const SizedBox(height: 16.0),
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the sheet
            },
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// A button that allows the user to select a single day.
class SelectDayButton extends StatelessWidget {
  const SelectDayButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>();

    return ElevatedButton(
      onPressed: () async {
        final selectedDay = await showDatePicker(
          context: context,
          initialDate: DateTime.now(),
          initialDatePickerMode: DatePickerMode.day,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

        if (!context.mounted) return;

        if (selectedDay != null) {
          dateCubit.selectDateRange(selectedDay, null, true);
        }
        Navigator.pop(context); // Close the sheet
      },
      child: const Text('Select Day'),
    );
  }
}

/// A button that allows the user to select a month.
class SelectMonthButton extends StatelessWidget {
  const SelectMonthButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>();

    return ElevatedButton(
      onPressed: () async {
        final selectedDay = await showDatePicker(
          context: context,
          initialDate: dateCubit.state.selectedStartDate,
          initialDatePickerMode: DatePickerMode.year,
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

        if (!context.mounted) return;

        if (selectedDay != null) {
          // Get the first and last day of the selected month
          final firstDayOfMonth =
              DateTime(selectedDay.year, selectedDay.month, 1);
          final lastDayOfMonth =
              DateTime(selectedDay.year, selectedDay.month + 1, 0);
          dateCubit.selectDateRange(firstDayOfMonth, lastDayOfMonth, false);
        }
        Navigator.pop(context); // Close the sheet
      },
      child: const Text('Select Month'),
    );
  }
}

/// A button that allows the user to select a date range.
class SelectDateRangeButton extends StatelessWidget {
  const SelectDateRangeButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>();

    return ElevatedButton(
      onPressed: () async {
        final selectedDateRange = await showDateRangePicker(
          context: context,
          initialEntryMode: DatePickerEntryMode.calendar,
          initialDateRange: DateTimeRange(
            start: dateCubit.state.selectedStartDate,
            end: dateCubit.state.selectedEndDate ?? DateTime.now(),
          ),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );

        if (!context.mounted) return;

        if (selectedDateRange != null) {
          dateCubit.selectDateRange(
            selectedDateRange.start,
            selectedDateRange.end,
            false,
          );
        }
        Navigator.pop(context); // Close the sheet
      },
      child: const Text('Select Date Range'),
    );
  }
}
