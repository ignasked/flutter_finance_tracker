import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/objectbox_repository/objectbox.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/cubit/transaction_form_cubit.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/main.dart';

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
          ? (context) => TransactionFormCubit(context.read<TransactionCubit>())
          : (context) => TransactionFormCubit.edit(
              context.read<TransactionCubit>(), transaction!, index),
      child: _AddTransactionForm(),
    );
  }
}

class _AddTransactionForm extends StatelessWidget {
  final _categories = ['Food', 'Travel', 'Taxes', 'Salary', 'Other'];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: BlocBuilder<TransactionFormCubit, TransactionFormState>(
          builder: (context, state) => Text(
            state.formType == TransactionFormType.addNew
                ? 'Add Transaction'
                : 'Edit Transaction',
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20.0),
        child: BlocListener<TransactionFormCubit, TransactionFormState>(
          listener: (context, state) {
            if (state.status.isSuccess) {
              Navigator.of(context).pop();
            } else {
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                      content: Text(state.errorMessage ?? 'Sign Up Failure')),
                );
            }
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
                        errorText:
                            state.isValid ? 'Title cannot be empty' : null),
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
                        errorText: state.amount.isNotValid
                            ? 'Amount cannot be empty'
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
                    items: _categories
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
                    onPressed: state.isValid == true
                        ? () => context
                            .read<TransactionFormCubit>()
                            .submitForm(context)
                        : null,
                    child: state.formType == TransactionFormType.addNew
                        ? const Text('Add Transaction')
                        : const Text('Save'),
                  ),
                  state.formType == TransactionFormType.edit
                      ? ElevatedButton(
                          onPressed: () => context
                              .read<TransactionFormCubit>()
                              .deleteTransaction(
                                  context.read<TransactionFormCubit>().index!,
                                  context),
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
