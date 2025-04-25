import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/transaction_repository/utils/transaction_utils.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:intl/intl.dart';

class TransactionFromScreen extends StatelessWidget {
  final Transaction? transaction; // Nullable for adding vs editing
  final int? index; // transaction index in transactionList
  const TransactionFromScreen({Key? key, this.transaction, this.index})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: transaction == null
          ? (context) => TransactionFormCubit()
          : (context) => TransactionFormCubit.edit(transaction!, index!),
      child: _TransactionForm(),
    );
  }
}

class _TransactionForm extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<TransactionFormCubit, TransactionFormState>(
          builder: (context, state) => Text(
            state.actionType == ActionType.addNew
                ? 'Add Transaction'
                : 'Edit Transaction',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: BlocListener<TransactionFormCubit, TransactionFormState>(
          listener: (context, state) {
            if (state.status.isSuccess && state.submittedTransaction != null) {
              Navigator.of(context).pop(state.submittedTransaction);
            } /*else if (state.status.isFailure) {
              // TODO: Show error
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                      content: Text(state.errorMessage ?? 'Unable to save')),
                );
            }*/
          },
          child: BlocBuilder<TransactionFormCubit, TransactionFormState>(
            builder: (context, state) {
              return Column(
                children: [
                  TextFormField(
                    key: const Key('transaction_form_title'),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .titleChanged(value),
                    decoration: InputDecoration(
                        labelText: 'Title',
                        border: const OutlineInputBorder(),
                        errorText: (state.status.isInitial == false &&
                                state.title.isNotValid)
                            ? 'Title cannot be empty'
                            : null),
                    initialValue: state.title.value,
                  ),
                  const SizedBox(height: 20),
                  TextFormField(
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .amountChanged(value),
                    decoration: InputDecoration(
                        labelText: 'Amount',
                        border: const OutlineInputBorder(),
                        errorText: (state.status.isInitial == false &&
                                state.amount.isNotValid)
                            ? state.amount.error.toString()
                            : null),
                    keyboardType: TextInputType.number,
                    initialValue: state.amount.value,
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: state.transactionType,
                    items: ['Income', 'Expense']
                        .map((type) =>
                            DropdownMenuItem(value: type, child: Text(type)))
                        .toList(),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .typeChanged(value!),
                    decoration: const InputDecoration(
                        labelText: 'Type', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  DropdownButtonFormField<String>(
                    value: categories.contains(state.category)
                        ? state.category
                        : categories.first,
                    items: categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .categoryChanged(value!),
                    decoration: const InputDecoration(
                        labelText: 'Category', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      );

                      if (!context.mounted) return;

                      if (selectedDate != null) {
                        context
                            .read<TransactionFormCubit>()
                            .dateChanged(selectedDate);
                      }
                    },
                    child: const Text('Select Date'),
                  ),
                  Text(DateFormat('yyyy-MM-dd').format(state.date)),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () =>
                        context.read<TransactionFormCubit>().submitForm(),
                    child: const Text('Save'),
                  ),
                  state.actionType == ActionType.edit
                      ? ElevatedButton(
                          onPressed: () => context
                              .read<TransactionFormCubit>()
                              .deleteTransaction(),
                          style: const ButtonStyle(
                              backgroundColor:
                                  WidgetStatePropertyAll(Colors.red)),
                          child: const Text('Delete Transaction',
                              style: TextStyle(color: Colors.white)),
                        )
                      : Container(),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
