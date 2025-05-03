import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart'; // Import TransactionResult
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/category_dropdown.dart';

class TransactionFormScreen extends StatelessWidget {
  final Transaction? transaction; // Nullable for adding vs editing
  //final int? index; // Transaction index in transactionList

  const TransactionFormScreen({super.key, this.transaction});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => transaction == null // Use _ for unused context
          ? TransactionFormCubit()
          : TransactionFormCubit.edit(transaction!),
      child: const _TransactionForm(),
    );
  }
}

class _TransactionForm extends StatelessWidget {
  const _TransactionForm();

  @override
  Widget build(BuildContext context) {
    // Don't access state directly here, as it might not be initialized yet
    // Instead, use BlocBuilder for all state-dependent widgets

    return BlocListener<TransactionFormCubit, TransactionFormState>(
      listener: (context, state) {
        if (state.status.isSuccess &&
            state.submittedTransactionResult != null) {
          // Pop with the result object
          Navigator.of(context).pop(state.submittedTransactionResult);
        }
        if (state.status.isFailure && state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!,
                    style: AppStyle.bodyText.copyWith(
                        color: ColorPalette.onError)), // Use onError color
                backgroundColor:
                    ColorPalette.errorContainer, // Use error container
                behavior: SnackBarBehavior.floating, // Modern look
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppStyle.borderRadiusMedium),
                ),
                margin: const EdgeInsets.all(AppStyle.paddingSmall),
              ),
            );
        }
      },
      child: Scaffold(
        // Prevent keyboard from pushing the AppBar up unnecessarily
        resizeToAvoidBottomInset: true,
        backgroundColor: AppStyle.backgroundColor,
        appBar: AppBar(
          title: BlocBuilder<TransactionFormCubit, TransactionFormState>(
            buildWhen: (previous, current) =>
                previous.actionType != current.actionType,
            builder: (context, state) => Text(
              state.actionType == ActionType.addNew
                  ? 'Add Transaction'
                  : 'Edit Transaction',
            ),
          ),
          backgroundColor: AppStyle.primaryColor,
          foregroundColor: ColorPalette.onPrimary,
          elevation: AppStyle.elevationSmall,
          iconTheme: const IconThemeData(color: ColorPalette.onPrimary),
        ),
        // *** New Body Structure for Centering/Reachability ***
        body: SafeArea(
          // Ensure content avoids notches/system areas
          child: Padding(
            // Apply horizontal padding here
            padding:
                const EdgeInsets.symmetric(horizontal: AppStyle.paddingMedium),
            child: Column(
              // Outer Column
              children: [
                Expanded(
                  // Make the scroll view take available vertical space
                  child: SingleChildScrollView(
                    // Apply vertical padding inside the scroll view
                    padding: const EdgeInsets.symmetric(
                        vertical: AppStyle
                            .paddingLarge), // Increased vertical padding
                    child: Column(
                      // Inner Column (Form content)
                      // Center content vertically IF space allows
                      mainAxisAlignment: MainAxisAlignment.center,
                      crossAxisAlignment: CrossAxisAlignment
                          .stretch, // Stretch buttons/fields horizontally
                      children: [
                        // --- Title Field ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (previous, current) =>
                              previous.title != current.title ||
                              previous.status != current.status,
                          builder: (context, state) => TextFormField(
                            key: const Key('transaction_form_title'),
                            initialValue: state.title.value,
                            style: AppStyle.bodyText,
                            autofocus: true,
                            decoration: AppStyle.getInputDecoration(
                              labelText: 'Title',
                              errorText: (state.title.isNotValid &&
                                      !state.status.isInitial)
                                  ? 'Title cannot be empty'
                                  : null,
                            ),
                            onChanged: (value) => context
                                .read<TransactionFormCubit>()
                                .titleChanged(value),
                            textInputAction: TextInputAction.next,
                          ),
                        ),
                        const SizedBox(height: AppStyle.paddingMedium),

                        // --- Amount Field ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (previous, current) =>
                              previous.amount != current.amount ||
                              previous.status != current.status ||
                              previous.selectedType !=
                                  current
                                      .selectedType, // Rebuild when type changes
                          builder: (context, state) => TextFormField(
                            onChanged: (value) => context
                                .read<TransactionFormCubit>()
                                .amountChanged(value),
                            decoration: AppStyle.getInputDecoration(
                              labelText: 'Amount',
                              errorText: (state.status.isFailure &&
                                      state.amount.isNotValid)
                                  ? state.amount.error?.toString()
                                  : null,
                            ).copyWith(
                              // Customize based on type
                              focusedBorder: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(
                                    AppStyle.borderRadiusMedium),
                                borderSide: BorderSide(
                                  color: state.selectedType ==
                                          TransactionType.income
                                      ? AppStyle.incomeColor
                                      : AppStyle.expenseColor,
                                  width: 2.0,
                                ),
                              ),
                              prefixIcon: Icon(
                                state.selectedType == TransactionType.income
                                    ? Icons.arrow_upward
                                    : Icons.arrow_downward,
                                color:
                                    state.selectedType == TransactionType.income
                                        ? AppStyle.incomeColor
                                        : AppStyle.expenseColor,
                              ),
                            ),
                            keyboardType: const TextInputType.numberWithOptions(
                                decimal: true),
                            initialValue: state.amount.value,
                            style: AppStyle.bodyText,
                          ),
                        ),

                        const SizedBox(height: AppStyle.paddingMedium),

                        // --- Transaction Type Selector ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (prev, curr) =>
                              prev.selectedType !=
                              curr.selectedType, // Rebuild when type changes
                          builder: (context, state) {
                            // Determine colors based on the selected state
                            final selectedColor =
                                state.selectedType == TransactionType.income
                                    ? AppStyle.incomeColor
                                    : AppStyle.expenseColor;

                            // Use a contrasting color for text/icon on the selected segment
                            const selectedForegroundColor = Colors.white;

                            // Color for the unselected segment's text/icon
                            const unselectedForegroundColor =
                                AppStyle.textColorSecondary;

                            // Background for the unselected segment (can be subtle)
                            const unselectedBackgroundColor =
                                AppStyle.cardColor;

                            // Border color for the unselected segment
                            const unselectedBorderColor = AppStyle.dividerColor;

                            return SegmentedButton<TransactionType>(
                              segments: const <ButtonSegment<TransactionType>>[
                                ButtonSegment(
                                    value: TransactionType.expense,
                                    label: Text('Expense'),
                                    icon: Icon(Icons.arrow_downward, size: 18)),
                                ButtonSegment(
                                    value: TransactionType.income,
                                    label: Text('Income'),
                                    icon: Icon(Icons.arrow_upward, size: 18)),
                              ],
                              selected: <TransactionType>{state.selectedType},
                              onSelectionChanged:
                                  (Set<TransactionType> newSelection) {
                                // Ensure only one selection remains (SegmentedButton handles this)
                                if (newSelection.isNotEmpty) {
                                  context
                                      .read<TransactionFormCubit>()
                                      .typeChanged(newSelection.first);
                                  // Optionally trigger category filtering here if needed
                                }
                              },
                              // --- Styling ---
                              // --- Styling using ButtonStyle directly ---
                              style: ButtonStyle(
                                // --- Foreground Color (Controls BOTH Text and Icon) ---
                                foregroundColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                        (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    // This color applies to text AND icon when selected
                                    return selectedForegroundColor; // Should be ColorPalette.onPrimary (white)
                                  }
                                  // This color applies to text AND icon when NOT selected
                                  return unselectedForegroundColor; // Should be AppStyle.textColorSecondary
                                }),
                                // --- Shape requires WidgetStateProperty wrapper here ---
                                shape: WidgetStateProperty.all<OutlinedBorder>(
                                  // Use .all for constant shape
                                  RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(
                                        AppStyle.borderRadiusMedium),
                                    side: BorderSide(
                                        color: unselectedBorderColor,
                                        width: 1.0),
                                  ),
                                ),

                                // --- Background Color (Still uses WidgetStateProperty) ---
                                backgroundColor:
                                    WidgetStateProperty.resolveWith<Color?>(
                                        (Set<WidgetState> states) {
                                  if (states.contains(WidgetState.selected)) {
                                    return selectedColor;
                                  }
                                  return unselectedBackgroundColor;
                                }),

                                // --- Text Style requires WidgetStateProperty wrapper ---
                                textStyle: WidgetStateProperty.all<TextStyle?>(
                                    // Use .all for constant text style
                                    AppStyle.captionStyle
                                        .copyWith(fontWeight: FontWeight.w500)),

                                // --- Padding requires WidgetStateProperty wrapper ---
                                padding:
                                    WidgetStateProperty.all<EdgeInsetsGeometry>(
                                        // Use .all for constant padding
                                        const EdgeInsets.symmetric(
                                            horizontal: AppStyle.paddingMedium,
                                            vertical:
                                                AppStyle.paddingSmall / 1.5)),

                                // Add elevation, mouse cursor etc. wrapped in WidgetStateProperty if needed
                                // elevation: WidgetStateProperty.all<double>(0), // Example

                                // Side property might be applicable here if shape doesn't handle it fully,
                                // but ButtonStyle's side also expects WidgetStateProperty<BorderSide?>?
                                // side: WidgetStateProperty.resolveWith<BorderSide?>((states) { ... })
                              ),
                              showSelectedIcon: true,
                              multiSelectionEnabled: false,
                            );
                          },
                        ),
                        const SizedBox(height: AppStyle.paddingMedium),

                        // --- Account Dropdown ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (previous, current) =>
                              previous.account != current.account,
                          builder: (context, state) {
                            return AccountDropdown(
                              selectedAccount: state.account,
                              onAccountChanged: (account) {
                                if (account != null) {
                                  context
                                      .read<TransactionFormCubit>()
                                      .accountChanged(account);
                                }
                              },
                            );
                          },
                        ),
                        const SizedBox(height: AppStyle.paddingMedium),

                        // --- Category Dropdown ---
                        const CategoryDropdown(),
                        const SizedBox(height: AppStyle.paddingMedium),

                        // --- Date Picker ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (previous, current) =>
                              previous.date != current.date,
                          builder: (context, state) {
                            return InkWell(
                              onTap: () => _selectDate(context, state.date),
                              borderRadius: BorderRadius.circular(
                                  AppStyle.borderRadiusMedium),
                              child: InputDecorator(
                                decoration: AppStyle.getInputDecoration(
                                  labelText: 'Date',
                                ).copyWith(
                                  contentPadding: const EdgeInsets.symmetric(
                                    horizontal: AppStyle.paddingMedium,
                                    vertical: AppStyle.paddingSmall,
                                  ),
                                  // Remove internal borders for a cleaner look when wrapping
                                  border: InputBorder.none,
                                  focusedBorder: InputBorder.none,
                                  enabledBorder: InputBorder.none,
                                  errorBorder: InputBorder.none,
                                  focusedErrorBorder: InputBorder.none,
                                  disabledBorder: InputBorder.none,
                                ),
                                child: Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildQuickDateButton(
                                        context, 'Today', DateTime.now()),
                                    const SizedBox(
                                        width: AppStyle.paddingXSmall),
                                    _buildQuickDateButton(
                                        context,
                                        'Yesterday',
                                        DateTime.now()
                                            .subtract(const Duration(days: 1))),
                                    const SizedBox(
                                        width: AppStyle.paddingXSmall),
                                    Text(
                                      DateFormat('yyyy-MM-dd')
                                          .format(state.date),
                                      style: AppStyle.bodyText,
                                    ),
                                    const Icon(
                                      Icons.calendar_today,
                                      color: AppStyle.primaryColor,
                                      size: 20,
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                        const SizedBox(
                            height:
                                AppStyle.paddingLarge), // Space before buttons

                        // --- Save Button ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (previous, current) =>
                              previous.status != current.status ||
                              previous.isValid !=
                                  current
                                      .isValid, // Also rebuild when validity changes
                          builder: (context, state) {
                            final bool isLoading = state.status.isInProgress;
                            return ElevatedButton.icon(
                              icon: isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: ColorPalette.onPrimary,
                                      ),
                                    )
                                  : const Icon(Icons.save,
                                      color: ColorPalette.onPrimary),
                              label: Text(isLoading ? 'Saving...' : 'Save'),
                              style: AppStyle.primaryButtonStyle,
                              onPressed: isLoading || !state.isValid
                                  ? null
                                  : () => context
                                      .read<TransactionFormCubit>()
                                      .submitForm(),
                            );
                          },
                        ),
                        const SizedBox(height: AppStyle.paddingSmall),

                        // --- Delete Button (Conditionally Shown) ---
                        BlocBuilder<TransactionFormCubit, TransactionFormState>(
                          buildWhen: (previous, current) =>
                              previous.actionType != current.actionType ||
                              previous.status != current.status,
                          builder: (context, state) {
                            if (state.actionType == ActionType.edit) {
                              final bool isLoading = state.status.isInProgress;
                              return ElevatedButton.icon(
                                icon: const Icon(Icons.delete_forever,
                                    color: ColorPalette.onPrimary),
                                label: const Text('Delete Transaction'),
                                style: AppStyle.dangerButtonStyle,
                                onPressed: isLoading
                                    ? null
                                    : () => _confirmDelete(context),
                              );
                            } else {
                              return const SizedBox.shrink();
                            }
                          },
                        ),
                        // No need for extra SizedBox at the end, padding is handled by SingleChildScrollView
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to show Date Picker (no changes needed here)
  Future<void> _selectDate(BuildContext context, DateTime initialDate) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppStyle.primaryColor,
                  onPrimary: ColorPalette.onPrimary,
                  surface: AppStyle.cardColor,
                  onSurface: AppStyle.textColorPrimary,
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppStyle.primaryColor,
              ),
            ),
            dialogBackgroundColor: AppStyle.cardColor,
          ),
          child: child!,
        );
      },
    );
    if (!context.mounted) return;
    if (selectedDate != null) {
      context.read<TransactionFormCubit>().dateChanged(selectedDate);
    }
  }

  // Helper function to show Delete Confirmation Dialog (no changes needed here)
  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
        ),
        title: const Text('Confirm Delete', style: AppStyle.heading2),
        content: const Text('Are you sure you want to delete this transaction?',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: AppStyle.textButtonStyle,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppStyle.dangerButtonStyle,
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirm == true && context.mounted) {
      context.read<TransactionFormCubit>().deleteTransaction();
    }
  }
}

// Helper method in _TransactionForm:
Widget _buildQuickDateButton(
    BuildContext context, String label, DateTime date) {
  return TextButton(
    onPressed: () => context.read<TransactionFormCubit>().dateChanged(date),
    style: TextButton.styleFrom(
      padding:
          const EdgeInsets.symmetric(horizontal: AppStyle.paddingSmall / 2),
      minimumSize: Size.zero, // Remove extra padding
      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      textStyle: AppStyle.captionStyle.copyWith(color: AppStyle.primaryColor),
    ),
    child: Text(label),
  );
}

// Extensions remain the same
extension TransactionFormStateResult on TransactionFormState {
  TransactionResult? get submittedTransactionResult {
    if (status.isSuccess) {
      if (actionType == ActionType.addNew && submittedTransaction != null) {
        return TransactionResult(
          actionType: ActionType.addNew,
          transaction: submittedTransaction!.transaction,
        ); // No index for new transactions
      } else if (actionType == ActionType.edit &&
          submittedTransaction != null) {
        return TransactionResult(
          actionType: ActionType.edit,
          transaction: submittedTransaction!.transaction,
        );
      } else if (actionType == ActionType.delete) {
        if (submittedTransaction != null) {
          return TransactionResult(
            actionType: ActionType.delete,
            transaction: submittedTransaction!
                .transaction, // Pass the transaction to be deleted
          );
        } else {
          return null; // Or adjust based on what the listener needs
        }
      }
    }
    return null;
  }
}

enum AmountInputError { empty, invalid }

extension AmountInputErrorExtension on AmountInputError {
  String get message {
    switch (this) {
      case AmountInputError.empty:
        return 'Amount cannot be empty';
      case AmountInputError.invalid:
        return 'Please enter a valid number';
    }
  }
}
