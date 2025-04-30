import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart'; // Updated import
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart'; // Import FilterCubit
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart'; // Import FilterState

class TransactionFilterSheet extends StatefulWidget {
  const TransactionFilterSheet({Key? key}) : super(key: key);

  static Future<void> show(BuildContext context) {
    // Provide FilterCubit to the sheet
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius:
            BorderRadius.vertical(top: Radius.circular(AppStyle.paddingMedium)),
      ),
      builder: (_) => BlocProvider.value(
        // Pass the existing FilterCubit from the context where show() is called
        value: BlocProvider.of<FilterCubit>(context),
        child: const TransactionFilterSheet(),
      ),
    );
  }

  @override
  State<TransactionFilterSheet> createState() => _TransactionFilterSheetState();
}

class _TransactionFilterSheetState extends State<TransactionFilterSheet> {
  late List<Category> _selectedCategories;
  late bool? _isIncome;
  // Add state for minAmount if you implement it

  @override
  void initState() {
    super.initState();
    // Initialize local state from FilterCubit's current state
    final filterState = context.read<FilterCubit>().state;
    _selectedCategories = List.from(filterState.selectedCategories);
    _isIncome = filterState.isIncome;
    // Initialize minAmount state here if needed
  }

  @override
  Widget build(BuildContext context) {
    // Read necessary data (category list)
    // TODO: Refactor - This dependency should be removed.
    // The list of categories should ideally come from CategoryRepository or FilterCubit state.
    final allCategories = context
        .read<TransactionsCubit>()
        .state
        .allCategories; // Updated context.read
    final filterCubit = context.read<FilterCubit>(); // Get FilterCubit instance

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppStyle.paddingLarge,
        right: AppStyle.paddingLarge,
        top: AppStyle.paddingLarge,
      ),
      child: SingleChildScrollView(
        // Make content scrollable
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'Filter Transactions',
              style: AppStyle.heading2,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyle.paddingLarge),

            // Category Filter
            Text('Categories', style: AppStyle.titleStyle),
            const SizedBox(height: AppStyle.paddingSmall),
            Wrap(
              spacing: AppStyle.paddingSmall,
              runSpacing: AppStyle.paddingSmall / 2,
              children: allCategories.map((category) {
                final isSelected =
                    _selectedCategories.any((c) => c.id == category.id);
                return FilterChip(
                  label: Text(category.title),
                  selected: isSelected,
                  onSelected: (selected) {
                    setState(() {
                      if (selected) {
                        _selectedCategories.add(category);
                      } else {
                        _selectedCategories
                            .removeWhere((c) => c.id == category.id);
                      }
                    });
                  },
                  selectedColor: Color(category.colorValue).withOpacity(0.7),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color:
                        isSelected ? Colors.white : AppStyle.textColorPrimary,
                  ),
                  backgroundColor: AppStyle.chipBackgroundColor,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
                    side: BorderSide(
                      color: isSelected
                          ? Colors.transparent
                          : AppStyle.primaryColor,
                    ),
                  ),
                );
              }).toList(),
            ),
            const SizedBox(height: AppStyle.paddingMedium),

            // Income/Expense Filter
            Text('Type', style: AppStyle.titleStyle),
            const SizedBox(height: AppStyle.paddingSmall),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                ChoiceChip(
                  label: const Text('All'),
                  selected: _isIncome == null,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isIncome = null);
                    }
                  },
                  selectedColor: AppStyle.primaryColor.withOpacity(0.7),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _isIncome == null
                        ? Colors.white
                        : AppStyle.textColorPrimary,
                  ),
                  backgroundColor: AppStyle.chipBackgroundColor,
                ),
                ChoiceChip(
                  label: const Text('Income'),
                  selected: _isIncome == true,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isIncome = true);
                    }
                  },
                  selectedColor: Colors.green.withOpacity(0.7),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _isIncome == true
                        ? Colors.white
                        : AppStyle.textColorPrimary,
                  ),
                  backgroundColor: AppStyle.chipBackgroundColor,
                ),
                ChoiceChip(
                  label: const Text('Expense'),
                  selected: _isIncome == false,
                  onSelected: (selected) {
                    if (selected) {
                      setState(() => _isIncome = false);
                    }
                  },
                  selectedColor: Colors.red.withOpacity(0.7),
                  checkmarkColor: Colors.white,
                  labelStyle: TextStyle(
                    color: _isIncome == false
                        ? Colors.white
                        : AppStyle.textColorPrimary,
                  ),
                  backgroundColor: AppStyle.chipBackgroundColor,
                ),
              ],
            ),
            const SizedBox(height: AppStyle.paddingLarge),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () {
                    // Reset local state and call FilterCubit's reset
                    setState(() {
                      _selectedCategories = [];
                      _isIncome = null;
                      // Reset minAmount state if needed
                    });
                    filterCubit
                        .resetFilters(); // Resets non-date filters in FilterCubit
                  },
                  child: const Text('Reset Filters',
                      style: TextStyle(color: AppStyle.warningColor)),
                ),
                ElevatedButton(
                  style: AppStyle.primaryButtonStyle,
                  onPressed: () {
                    // Apply filters by calling FilterCubit methods
                    filterCubit.changeSelectedCategories(_selectedCategories);
                    filterCubit.changeIsIncome(_isIncome);
                    // filterCubit.changeMinAmount(_minAmount); // If implemented
                    Navigator.pop(context); // Close the sheet
                  },
                  child: const Text('Apply'),
                ),
              ],
            ),
            const SizedBox(
                height: AppStyle.paddingMedium), // Add some bottom padding
          ],
        ),
      ),
    );
  }
}
