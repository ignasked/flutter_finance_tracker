import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart'; // Import TransactionResult
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/category_dropdown.dart';

class TransactionFromScreen extends StatelessWidget {
  final Transaction? transaction; // Nullable for adding vs editing
  final int? index; // Transaction index in transactionList

  const TransactionFromScreen({super.key, this.transaction, this.index});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => transaction == null // Use _ for unused context
          ? TransactionFormCubit()
          : TransactionFormCubit.edit(transaction!, index!),
      child: const _TransactionForm(),
    );
  }
}

class _TransactionForm extends StatelessWidget {
  const _TransactionForm({super.key});

  @override
  Widget build(BuildContext context) {
    // Get the initial state once - needed for dropdowns if they aren't rebuilt by BlocBuilder
    final initialState = context.read<TransactionFormCubit>().state;

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
        backgroundColor: AppStyle.backgroundColor,
        appBar: AppBar(
          title: BlocBuilder<TransactionFormCubit, TransactionFormState>(
            // Build only when actionType changes
            buildWhen: (previous, current) =>
                previous.actionType != current.actionType,
            builder: (context, state) => Text(
              state.actionType == ActionType.addNew
                  ? 'Add Transaction'
                  : 'Edit Transaction',
              // Style inherits from AppBarTheme usually, but can override
              // style: AppStyle.heading2.copyWith(color: ColorPalette.onPrimary),
            ),
          ),
          backgroundColor: AppStyle.primaryColor,
          foregroundColor:
              ColorPalette.onPrimary, // Ensures icon/text color contrast
          elevation: AppStyle.elevationSmall, // Add subtle elevation
          iconTheme: const IconThemeData(
              color: ColorPalette.onPrimary), // Explicit back arrow color
        ),
        body: Padding(
          // Consistent padding
          padding: const EdgeInsets.all(AppStyle.paddingMedium),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons
              children: [
                // --- Title Field ---
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.title != current.title ||
                      previous.status !=
                          current.status, // Rebuild on status change for error
                  builder: (context, state) => TextFormField(
                    key: const Key('transaction_form_title'),
                    initialValue: state.title.value,
                    style: AppStyle.bodyText,
                    decoration: AppStyle.getInputDecoration(
                      // Use styled decoration
                      labelText: 'Title',
                      errorText: (state.title.isNotValid &&
                              !state.status
                                  .isPure) // Show error only if invalid and touched/submitted
                          ? 'Title cannot be empty'
                          : null,
                    ),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .titleChanged(value),
                    textInputAction:
                        TextInputAction.next, // Improve keyboard navigation
                  ),
                ),
                const SizedBox(height: AppStyle.paddingMedium),

                // --- Amount Field ---
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.amount != current.amount ||
                      previous.status !=
                          current.status, // Rebuild on status change for error
                  builder: (context, state) => TextFormField(
                    key: const Key('transaction_form_amount'),
                    initialValue: state.amount.value,
                    style: AppStyle.bodyText,
                    decoration: AppStyle.getInputDecoration(
                      // Use styled decoration
                      labelText: 'Amount',
                      // Consider adding prefix/suffix for currency symbol if needed
                      // prefixText: Defaults().defaultCurrencySymbol + ' ',
                      errorText: (state.amount.isNotValid &&
                              !state.status.isPure)
                          ? state.amount.error
                              ?.message // Use error message from AmountInputError
                          : null,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .amountChanged(value),
                    textInputAction: TextInputAction.next,
                  ),
                ),
                const SizedBox(height: AppStyle.paddingMedium),

                // --- Account Dropdown ---
                // Assuming AccountDropdown internally uses AppStyle.getInputDecoration
                AccountDropdown(
                  selectedAccount:
                      initialState.account, // Pass initial state value
                  onAccountChanged: (account) {
                    if (account != null) {
                      context
                          .read<TransactionFormCubit>()
                          .accountChanged(account);
                    }
                  },
                ),
                const SizedBox(height: AppStyle.paddingMedium),

                // --- Category Dropdown ---
                // Assuming CategoryDropdown internally uses AppStyle.getInputDecoration
                const CategoryDropdown(),
                const SizedBox(height: AppStyle.paddingMedium),

                // --- Date Picker ---
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.date != current.date,
                  builder: (context, state) {
                    return InkWell(
                      // Make the whole row tappable
                      onTap: () => _selectDate(context, state.date),
                      borderRadius:
                          BorderRadius.circular(AppStyle.borderRadiusMedium),
                      child: InputDecorator(
                        // Wrap in InputDecorator for consistent look
                        decoration: AppStyle.getInputDecoration(
                          labelText: 'Date',
                          contentPadding: const EdgeInsets.symmetric(
                            // Adjust padding for icon
                            horizontal: AppStyle.paddingMedium,
                            vertical:
                                AppStyle.paddingSmall, // Less vertical padding
                          ),
                        ).copyWith(
                            border: InputBorder.none,
                            focusedBorder: InputBorder.none,
                            enabledBorder:
                                InputBorder.none), // Remove internal border
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              DateFormat('yyyy-MM-dd').format(state.date),
                              style: AppStyle.bodyText,
                            ),
                            const Icon(
                              Icons.calendar_today,
                              color: AppStyle.primaryColor,
                              size: 20, // Slightly smaller icon
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(
                    height: AppStyle.paddingLarge), // More space before buttons

                // --- Save Button ---
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  // Rebuild only when status changes to avoid unnecessary rebuilds
                  buildWhen: (previous, current) =>
                      previous.status != current.status,
                  builder: (context, state) {
                    final bool isLoading = state.status.isInProgress;
                    return ElevatedButton.icon(
                      icon: isLoading
                          ? const SizedBox(
                              // Loading indicator
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
                      // Disable button and change text when loading
                      onPressed: isLoading ||
                              !state.isValid // Also disable if form is invalid
                          ? null
                          : () =>
                              context.read<TransactionFormCubit>().submitForm(),
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
                        style: AppStyle.dangerButtonStyle, // Use danger style
                        onPressed: isLoading
                            ? null
                            : () =>
                                _confirmDelete(context), // Extract dialog logic
                      );
                    } else {
                      return const SizedBox
                          .shrink(); // Don't show for new transactions
                    }
                  },
                ),
                const SizedBox(
                    height: AppStyle.paddingMedium), // Padding at the bottom
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper function to show Date Picker
  Future<void> _selectDate(BuildContext context, DateTime initialDate) async {
    final selectedDate = await showDatePicker(
      context: context,
      initialDate: initialDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
      // Apply theme for consistency
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: Theme.of(context).colorScheme.copyWith(
                  primary: AppStyle.primaryColor, // Use AppStyle color
                  onPrimary: ColorPalette.onPrimary,
                  surface: AppStyle.cardColor, // Dialog background
                  onSurface: AppStyle.textColorPrimary, // Dialog text
                ),
            textButtonTheme: TextButtonThemeData(
              style: TextButton.styleFrom(
                foregroundColor: AppStyle.primaryColor, // Button text color
              ),
            ),
            dialogBackgroundColor: AppStyle.cardColor,
          ),
          child: child!,
        );
      },
    );

    // Check if the widget is still mounted before calling context dependent methods
    if (!context.mounted) return;

    if (selectedDate != null) {
      context.read<TransactionFormCubit>().dateChanged(selectedDate);
    }
  }

  // Helper function to show Delete Confirmation Dialog
  Future<void> _confirmDelete(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardColor, // Use card color
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(
              AppStyle.borderRadiusMedium), // Consistent radius
        ),
        title: const Text('Confirm Delete', style: AppStyle.heading2),
        content: const Text('Are you sure you want to delete this transaction?',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: AppStyle.textButtonStyle, // Use text button style
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            // Use elevated button for destructive confirmation
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppStyle.dangerButtonStyle, // Use danger style
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    // Check if the widget is still mounted before calling context dependent methods
    if (confirm == true && context.mounted) {
      context.read<TransactionFormCubit>().deleteTransaction();
    }
  }
}

// Add this to your TransactionFormState if it doesn't exist
// To pop with a result object instead of just the transaction
extension TransactionFormStateResult on TransactionFormState {
  TransactionResult? get submittedTransactionResult {
    if (status.isSuccess) {
      if (actionType == ActionType.addNew && submittedTransaction != null) {
        return TransactionResult(
            type: TransactionResultType.added,
            transaction: submittedTransaction!);
      } else if (actionType == ActionType.edit &&
          submittedTransaction != null &&
          originalIndex != null) {
        return TransactionResult(
            type: TransactionResultType.edited,
            transaction: submittedTransaction!,
            index: originalIndex);
      } else if (actionType == ActionType.delete && originalIndex != null) {
        return TransactionResult(
            type: TransactionResultType.deleted, index: originalIndex);
      }
    }
    return null;
  }
}

// Define AmountInputError if you haven't already (example)
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
