import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
// Import Transaction
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart'; // Import DataManagementCubit
import 'package:money_owl/front/shared/data_management_cubit/date_cubit.dart';

/// A widget that displays a date bar with navigation buttons and a calendar button.
/// It allows users to navigate between dates and open a date selection sheet.
class DateBarWidget extends StatelessWidget {
  const DateBarWidget({
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DateCubit, DateState>(
      builder: (context, state) {
        final dateCubit = context.read<DateCubit>();

        return Container(
          padding: const EdgeInsets.symmetric(
              vertical: AppStyle.paddingSmall / 2,
              horizontal: AppStyle.paddingMedium), // Use AppStyle padding
          decoration: BoxDecoration(
            color: AppStyle.cardColor, // Use AppStyle card color
            borderRadius: BorderRadius.circular(
                AppStyle.paddingSmall), // Use AppStyle padding
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30), // Softer shadow
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              // Previous Button
              IconButton(
                  icon: const Icon(Icons.arrow_left,
                      color: AppStyle.primaryColor), // Use AppStyle color
                  onPressed: dateCubit.moveToPrevious),

              // Date Range Display
              const DateRangeDisplay(),

              // Next Button
              IconButton(
                  icon: const Icon(Icons.arrow_right,
                      color: AppStyle.primaryColor), // Use AppStyle color
                  onPressed: dateCubit.moveToNext),

              // Calendar Button
              IconButton(
                icon: const Icon(Icons.calendar_today,
                    color: AppStyle.primaryColor), // Use AppStyle color
                onPressed: () {
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor:
                        AppStyle.backgroundColor, // Use AppStyle background
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                              AppStyle.paddingMedium)), // Use AppStyle padding
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
            style: AppStyle.titleStyle, // Use AppStyle title style
          ),
        );
      },
    );
  }

  /// Formats the date range for display.
  ///
  /// If [endDate] is null, only the [startDate] is displayed.
  /// Otherwise, the range is displayed as "startDate - endDate".
  String _formatDateRange(DateTime? startDate, DateTime? endDate) {
    final dateFormat = DateFormat('yyyy.MM.dd');
    if (startDate != null && endDate == null) {
      return dateFormat.format(startDate); // Single day
    } else if (startDate != null && endDate != null) {
      // Check if start and end date are the same day
      if (startDate.year == endDate.year &&
          startDate.month == endDate.month &&
          startDate.day == endDate.day) {
        return dateFormat.format(startDate);
      }
      return '${dateFormat.format(startDate)} - ${dateFormat.format(endDate)}'; // Date range
    }
    // Fallback for unexpected null combinations or initial state
    return 'Select Date';
  }
}

/// A bottom sheet widget that provides options for selecting a date filter.
///
/// Users can choose to select a single day, a month, or a date range.
class DateSelectionOptionsSheet extends StatelessWidget {
  const DateSelectionOptionsSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>(); // Get cubit instance
    // Read DataManagementCubit to access all transactions
    final dataManagementCubit = context.read<DataManagementCubit>();

    return Padding(
      padding:
          const EdgeInsets.all(AppStyle.paddingLarge), // Use AppStyle padding
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons
        children: [
          const Text(
            'Date Filter',
            style: AppStyle.heading2, // Use AppStyle heading
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppStyle.paddingLarge), // Use AppStyle padding
          const SelectDayButton(),
          const SizedBox(
              height: AppStyle.paddingMedium), // Use AppStyle padding
          const SelectMonthButton(),
          const SizedBox(
              height: AppStyle.paddingMedium), // Use AppStyle padding
          const SelectDateRangeButton(),
          const SizedBox(
              height: AppStyle.paddingMedium), // Use AppStyle padding
          // --- Modify "All History" Button ---
          ElevatedButton(
            style: AppStyle.primaryButtonStyle,
            onPressed: () {
              final allTransactions = dataManagementCubit.state.allTransactions;
              if (allTransactions.isNotEmpty) {
                // Find the actual min and max dates from all transactions
                DateTime minDate = allTransactions.last.date;
                DateTime maxDate = allTransactions.first.date;

                for (var tx in allTransactions) {
                  if (tx.date.isBefore(minDate)) {
                    minDate = tx.date;
                  }
                  if (tx.date.isAfter(maxDate)) {
                    maxDate = tx.date;
                  }
                }
                // Select the full range covering all transactions
                dateCubit.selectDateRange(minDate, maxDate, false);
              } else {
                // Optional: Show a message if no transactions exist
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('No transactions found.')),
                );
              }
              Navigator.pop(context); // Close the sheet
            },
            child: const Text('Select Full Range'), // Changed text
          ),
          // --- End Modify Button ---
          const SizedBox(height: AppStyle.paddingLarge), // Use AppStyle padding
          ElevatedButton(
            onPressed: () {
              Navigator.pop(context); // Close the sheet
            },
            style: AppStyle
                .secondaryButtonStyle, // Use AppStyle secondary button style
            child: const Text('Done'),
          ),
        ],
      ),
    );
  }
}

/// A button that allows the user to select a single day.
class SelectDayButton extends StatelessWidget {
  const SelectDayButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>();

    return ElevatedButton(
      style: AppStyle.primaryButtonStyle, // Use AppStyle primary button style
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
  const SelectMonthButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>();

    return ElevatedButton(
      style: AppStyle.primaryButtonStyle, // Use AppStyle primary button style
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
  const SelectDateRangeButton({super.key});

  @override
  Widget build(BuildContext context) {
    final dateCubit = context.read<DateCubit>();

    return ElevatedButton(
      style: AppStyle.primaryButtonStyle, // Use AppStyle primary button style
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
