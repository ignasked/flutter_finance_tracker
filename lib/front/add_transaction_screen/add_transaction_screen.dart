import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/utils/transaction_utils.dart';
import 'package:pvp_projektas/backend/objectbox_repository/objectbox.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/cubit/transaction_form_cubit.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/main.dart';
import 'package:intl/intl.dart';

class AddTransactionScreen extends StatelessWidget {
  final Transaction? transaction; // Nullable for adding vs editing
  final int? index; // transaction index in transactionList
  const AddTransactionScreen({Key? key, this.transaction, this.index})
      : super(key: key);

  //@override
  //State<AddTransactionScreen> createState() => _AddTransactionScreen();

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: transaction == null
          ? (context) => TransactionFormCubit()
          : (context) => TransactionFormCubit.edit(transaction!, index!),
      child: _AddTransactionForm(),
    );
  }
}

class _AddTransactionForm extends StatelessWidget {
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
                        border: OutlineInputBorder(),
                        errorText: (state.status.isInitial == false && state.title.isNotValid)
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
                        border: OutlineInputBorder(),
                        errorText: (state.status.isInitial == false && state.amount.isNotValid)
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
                    value: state.category,
                    items: categories
                        .map((category) => DropdownMenuItem(
                            value: category, child: Text(category)))
                        .toList(),
                    onChanged: (value) => context
                        .read<TransactionFormCubit>()
                        .categoryChanged(value!),
                    decoration: const InputDecoration(
                        labelText: 'Category', border: OutlineInputBorder()),
                  ),
                  const SizedBox(height: 20),
                  ElevatedButton(
                    onPressed: () {
                      showDatePicker(
                        context: context,
                        initialDate: DateTime.now(),
                        firstDate: DateTime(1900),
                        lastDate: DateTime(2100),
                      ).then((selectedDate) {
                        if (selectedDate != null) {
                          context.read<TransactionFormCubit>().dateChanged(selectedDate);
                        }
                      });
                    },
                    child: Text('Select Date'),
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
