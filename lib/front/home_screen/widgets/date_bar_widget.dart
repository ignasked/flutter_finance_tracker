import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/home_screen/cubit/date_cubit.dart';

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
        final dateFormat = DateFormat('MMM dd, yyyy');
        final dateRangeText = state.selectedEndDate == null
            ? dateFormat.format(state.selectedStartDate) // Single day
            : '${dateFormat.format(state.selectedStartDate)} - ${dateFormat.format(state.selectedEndDate!)}'; // Date range

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
                  onPressed: () {
                    dateCubit.moveToPrevious();

                    if (dateCubit.state.selectedEndDate != null) {
                      context.read<AccountTransactionCubit>().changeDateRange(
                            dateCubit.state.selectedStartDate,
                            dateCubit.state.selectedEndDate!,
                          );
                    } else {
                      context.read<AccountTransactionCubit>().changeSingleDay(
                            dateCubit.state.selectedStartDate,
                          );
                    }
                  }),

              // Date Range Display
              Expanded(
                child: Text(
                  dateRangeText,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),

              // Next Button
              IconButton(
                  icon: const Icon(Icons.arrow_right, color: Colors.blue),
                  onPressed: () {
                    dateCubit.moveToNext();

                    if (dateCubit.state.selectedEndDate != null) {
                      context.read<AccountTransactionCubit>().changeDateRange(
                            dateCubit.state.selectedStartDate,
                            dateCubit.state.selectedEndDate!,
                          );
                    } else {
                      context.read<AccountTransactionCubit>().changeSingleDay(
                            dateCubit.state.selectedStartDate,
                          );
                    }
                  }),
              // Calendar Button
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.blue),
                onPressed: () => DateSelectionSheet.show(context),
              ),
            ],
          ),
        );
      },
    );
  }
}

class DateSelectionSheet extends StatelessWidget {
  const DateSelectionSheet({Key? key}) : super(key: key);

  /// Static method to show the filter sheet
  static void show(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => const DateSelectionSheet(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final txCubit = context.read<AccountTransactionCubit>();
    final dateCubit = context.read<DateCubit>();

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
          ElevatedButton(
            onPressed: () async {
              final selectedDay = await showDatePicker(
                context: context,
                initialDate: dateCubit.state.selectedStartDate,
                initialDatePickerMode: DatePickerMode.day,
                firstDate: DateTime(2000),
                lastDate: DateTime(2100),
              );

              if (!context.mounted) return;

              if (selectedDay != null) {
                txCubit.changeSingleDay(selectedDay);
                dateCubit.selectDateRange(selectedDay, null);
              }
              Navigator.pop(context); // Close the sheet
            },
            child: const Text('Select Day'),
          ),
          const SizedBox(height: 8.0),
          ElevatedButton(
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
                txCubit.changeDateRange(
                  selectedDateRange.start,
                  selectedDateRange.end,
                );

                dateCubit.selectDateRange(
                  selectedDateRange.start,
                  selectedDateRange.end,
                );
              }
              Navigator.pop(context); // Close the sheet
            },
            child: const Text('Select Date Range'),
          ),
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
