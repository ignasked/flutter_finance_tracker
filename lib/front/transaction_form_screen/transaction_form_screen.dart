import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/category_dropdown.dart';

class TransactionFromScreen extends StatelessWidget {
  final Transaction? transaction; // Nullable for adding vs editing
  final int? index; // Transaction index in transactionList

  const TransactionFromScreen({Key? key, this.transaction, this.index})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: transaction == null
          ? (context) => TransactionFormCubit()
          : (context) => TransactionFormCubit.edit(transaction!, index!),
      child: const _TransactionForm(),
    );
  }
}

class _TransactionForm extends StatelessWidget {
  const _TransactionForm({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Get the initial state once - this will be used for widgets that don't need rebuilding
    final initialState = context.read<TransactionFormCubit>().state;

    return BlocListener<TransactionFormCubit, TransactionFormState>(
      listener: (context, state) {
        if (state.status.isSuccess && state.submittedTransaction != null) {
          Navigator.of(context).pop(state.submittedTransaction);
        }
        if (state.status.isFailure && state.errorMessage != null) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text(state.errorMessage!,
                    style: AppStyle.bodyText.copyWith(color: Colors.white)),
                backgroundColor: AppStyle.expenseColor,
              ),
            );
        }
      },
      child: Scaffold(
        backgroundColor: AppStyle.backgroundColor,
        appBar: AppBar(
          title: BlocBuilder<TransactionFormCubit, TransactionFormState>(
            buildWhen: (previous, current) =>
                previous.actionType != current.actionType,
            builder: (context, state) => Text(
              state.actionType == ActionType.addNew
                  ? 'Add Transaction'
                  : 'Edit Transaction',
              style: AppStyle.heading2,
            ),
          ),
          backgroundColor: AppStyle.primaryColor,
          foregroundColor: Colors.white,
        ),
        body: Padding(
          padding: const EdgeInsets.all(AppStyle.paddingLarge),
          child: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Title field
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.title != current.title ||
                      previous.status != current.status,
                  builder: (context, state) => TextFormField(
                    key: const Key('transaction_form_title'),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .titleChanged(value),
                    decoration: InputDecoration(
                      labelText: 'Title',
                      labelStyle: AppStyle.bodyText,
                      border: const OutlineInputBorder(),
                      errorStyle: const TextStyle(color: AppStyle.expenseColor),
                      errorText:
                          (state.status.isFailure && state.title.isNotValid)
                              ? 'Title cannot be empty'
                              : null,
                    ),
                    initialValue: state.title.value,
                    style: AppStyle.bodyText,
                  ),
                ),

                const SizedBox(height: AppStyle.paddingMedium),

                // Amount field
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.amount != current.amount ||
                      previous.status != current.status,
                  builder: (context, state) => TextFormField(
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .amountChanged(value),
                    decoration: InputDecoration(
                      labelText: 'Amount',
                      labelStyle: AppStyle.bodyText,
                      border: const OutlineInputBorder(),
                      errorStyle: const TextStyle(color: AppStyle.expenseColor),
                      errorText:
                          (state.status.isFailure && state.amount.isNotValid)
                              ? state.amount.error?.toString()
                              : null,
                    ),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    initialValue: state.amount.value,
                    style: AppStyle.bodyText,
                  ),
                ),

                const SizedBox(height: AppStyle.paddingMedium),

                // Account dropdown - not wrapped in BlocBuilder to prevent unnecessary rebuilds
                AccountDropdown(
                  selectedAccount: initialState.account,
                  onAccountChanged: (account) {
                    if (account != null) {
                      context
                          .read<TransactionFormCubit>()
                          .accountChanged(account);
                    }
                  },
                ),

                const SizedBox(height: AppStyle.paddingMedium),

                // Category dropdown
                const CategoryDropdown(),

                const SizedBox(height: AppStyle.paddingMedium),

                // Date picker
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.date != current.date,
                  builder: (context, state) => Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Date: ${DateFormat('yyyy-MM-dd').format(state.date)}',
                        style: AppStyle.bodyText,
                      ),
                      TextButton.icon(
                        icon: const Icon(Icons.calendar_today,
                            color: AppStyle.primaryColor),
                        label: const Text('Select Date',
                            style: TextStyle(color: AppStyle.primaryColor)),
                        onPressed: () async {
                          final selectedDate = await showDatePicker(
                            context: context,
                            initialDate: state.date,
                            firstDate: DateTime(2000),
                            lastDate: DateTime(2100),
                            builder: (context, child) {
                              return Theme(
                                data: Theme.of(context).copyWith(
                                  colorScheme:
                                      Theme.of(context).colorScheme.copyWith(
                                            primary: AppStyle.primaryColor,
                                            onPrimary: Colors.white,
                                          ),
                                  textButtonTheme: TextButtonThemeData(
                                    style: TextButton.styleFrom(
                                      foregroundColor: AppStyle.primaryColor,
                                    ),
                                  ),
                                ),
                                child: child!,
                              );
                            },
                          );

                          if (!context.mounted) return;

                          if (selectedDate != null) {
                            context
                                .read<TransactionFormCubit>()
                                .dateChanged(selectedDate);
                          }
                        },
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: AppStyle.paddingLarge),

                // Save button
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.status != current.status,
                  builder: (context, state) => ElevatedButton.icon(
                    icon: const Icon(Icons.save, color: Colors.white),
                    label: const Text('Save'),
                    style: AppStyle.primaryButtonStyle,
                    onPressed: state.status.isInProgress
                        ? null
                        : () =>
                            context.read<TransactionFormCubit>().submitForm(),
                  ),
                ),

                const SizedBox(height: AppStyle.paddingSmall),

                // Delete button - conditionally shown
                BlocBuilder<TransactionFormCubit, TransactionFormState>(
                  buildWhen: (previous, current) =>
                      previous.actionType != current.actionType ||
                      previous.status != current.status,
                  builder: (context, state) => state.actionType ==
                          ActionType.edit
                      ? ElevatedButton.icon(
                          icon: const Icon(Icons.delete_forever,
                              color: Colors.white),
                          label: const Text('Delete Transaction'),
                          style: AppStyle.secondaryButtonStyle,
                          onPressed: state.status.isInProgress
                              ? null
                              : () async {
                                  final confirm = await showDialog<bool>(
                                    context: context,
                                    builder: (dialogContext) => AlertDialog(
                                      title: const Text('Confirm Delete',
                                          style: AppStyle.heading2),
                                      content: const Text(
                                          'Are you sure you want to delete this transaction?',
                                          style: AppStyle.bodyText),
                                      backgroundColor: AppStyle.cardColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(
                                            AppStyle.paddingMedium),
                                      ),
                                      actions: [
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                              dialogContext, false),
                                          style: AppStyle.secondaryButtonStyle,
                                          child: const Text('Cancel'),
                                        ),
                                        TextButton(
                                          onPressed: () => Navigator.pop(
                                              dialogContext, true),
                                          style: TextButton.styleFrom(
                                            foregroundColor:
                                                AppStyle.expenseColor,
                                          ),
                                          child: const Text('Delete'),
                                        ),
                                      ],
                                    ),
                                  );

                                  if (confirm == true && context.mounted) {
                                    context
                                        .read<TransactionFormCubit>()
                                        .deleteTransaction();
                                  }
                                },
                        )
                      : const SizedBox.shrink(),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
