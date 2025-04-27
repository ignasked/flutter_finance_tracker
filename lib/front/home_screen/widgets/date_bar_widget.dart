import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/home_screen/cubit/date_cubit.dart';

class DateBarWidget extends StatelessWidget {
  const DateBarWidget({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DateCubit, DateState>(
      builder: (context, state) {
        // Format the selected date or date range
        final dateFormat = DateFormat('MMM dd, yyyy');
        final dateRangeText = state.selectedEndDate == null
            ? dateFormat.format(state.selectedStartDate) // Single day
            : '${dateFormat.format(state.selectedStartDate)} - ${dateFormat.format(state.selectedEndDate!)}'; // Date range

        return Container(
          padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 16.0),
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
                onPressed: () => context.read<DateCubit>().moveToPrevious(),
              ),

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
                onPressed: () => context.read<DateCubit>().moveToNext(),
              ),

              // Calendar Button
              IconButton(
                icon: const Icon(Icons.calendar_today, color: Colors.blue),
                onPressed: null,
              ),
            ],
          ),
        );
      },
    );
  }
}
