import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/utils/enums.dart';

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
            }
          },
          child: BlocBuilder<TransactionFormCubit, TransactionFormState>(
            builder: (context, state) {
              return Column(
                children: [
                  // Title Input
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
                          : null,
                    ),
                    initialValue: state.title.value,
                  ),
                  const SizedBox(height: 20),

                  // Amount Input
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
                          : null,
                    ),
                    keyboardType: TextInputType.number,
                    initialValue: state.amount.value,
                  ),
                  const SizedBox(height: 20),

                  // // Transaction Type Dropdown
                  // DropdownButtonFormField<TransactionType>(
                  //   value: state.transactionType,
                  //   items: [TransactionType.income, TransactionType.expense]
                  //       .map((type) => DropdownMenuItem(
                  //             value: type,
                  //             child: Text(type == TransactionType.income
                  //                 ? 'Income'
                  //                 : 'Expense'),
                  //           ))
                  //       .toList(),
                  //   onChanged: (value) => context
                  //       .read<TransactionFormCubit>()
                  //       .typeChanged(value!),
                  //   decoration: const InputDecoration(
                  //       labelText: 'Type', border: OutlineInputBorder()),
                  // ),
                  // const SizedBox(height: 20),

                  // Category Dropdown
                  FutureBuilder<List<Category>>(
                    future: CategoryRepository.create()
                        .then((repo) => repo.getCategories()),
                    builder: (context, snapshot) {
                      if (snapshot.connectionState == ConnectionState.waiting) {
                        return const CircularProgressIndicator();
                      }

                      if (snapshot.hasError) {
                        return const Text('Error loading categories');
                      }

                      final categories = snapshot.data ?? [];

                      return DropdownButtonFormField<Category>(
                        value: state.category,
                        items: categories.map((category) {
                          return DropdownMenuItem(
                            value: category,
                            child: Row(
                              children: [
                                Icon(category.icon, color: category.color),
                                const SizedBox(width: 8),
                                Text(category.title),
                              ],
                            ),
                          );
                        }).toList(),
                        onChanged: (value) => context
                            .read<TransactionFormCubit>()
                            .categoryChanged(value!),
                        decoration: const InputDecoration(
                          labelText: 'Category',
                          border: OutlineInputBorder(),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 20),

                  // Date Picker
                  ElevatedButton(
                    onPressed: () async {
                      final selectedDate = await showDatePicker(
                        context: context,
                        initialDate: state.date,
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

                  // Save Button
                  ElevatedButton(
                    onPressed: () =>
                        context.read<TransactionFormCubit>().submitForm(),
                    child: const Text('Save'),
                  ),

                  // Delete Button (only for editing)
                  if (state.actionType == ActionType.edit)
                    ElevatedButton(
                      onPressed: () => context
                          .read<TransactionFormCubit>()
                          .deleteTransaction(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.red,
                      ),
                      child: const Text(
                        'Delete Transaction',
                        style: TextStyle(color: Colors.white),
                      ),
                    ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}
