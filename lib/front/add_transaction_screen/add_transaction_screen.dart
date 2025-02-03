import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/objectbox_repository/objectbox.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/main.dart';

enum EditorType { add_new, edit }

class AddTransactionScreen extends StatefulWidget {
  final Transaction? transaction; // Nullable for adding vs editing
  final int? index; // shows transaction index in transactionList
  const AddTransactionScreen({Key? key, this.transaction, this.index}) : super(key: key);

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreen();
}

class _AddTransactionScreen extends State<AddTransactionScreen> {
  final _formKey = GlobalKey<FormState>();

  // Form field controllers
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  String _selectedType = 'Income'; // Default value for Type
  String _selectedCategory = 'Food'; // Default value for Category
  DateTime _selectedDate = DateTime.now();
  EditorType _editorType = EditorType.add_new;

  // List of categories
  final List<String> _categories = [
    'Food',
    'Travel',
    'Taxes',
    'Salary',
    'Other'
  ];

  @override
  void initState() {
    super.initState();

    if (widget.transaction != null) {
      _editorType = EditorType.edit;
      _titleController.text = widget.transaction!.title;
      _amountController.text = widget.transaction!.amount.toString();
      widget.transaction!.isIncome
          ? _selectedType = 'Income'
          : _selectedType = 'Expense';
      _selectedCategory = widget.transaction!.category;
      _selectedDate = widget.transaction!.date;
    } else {
      _editorType = EditorType.add_new;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: _editorType == EditorType.add_new
            ? const Text('Add Transaction')
            : const Text('Edit Transaction'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Form(
            key: _formKey,
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  // Title Input
                  TextFormField(
                    controller: _titleController,
                    decoration: const InputDecoration(
                      labelText: 'Title',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter a title';
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Amount Input
                  TextFormField(
                    controller: _amountController,
                    decoration: const InputDecoration(
                      labelText: 'Amount',
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                    validator: (value) {
                      if (value == null || value.isEmpty) {
                        return 'Please enter an amount';
                      }

                      if (double.tryParse(value) == null) {
                        return 'Please enter a valid number';
                      }

                      final regex = RegExp(r'^\d+(\.\d{0,2})?$');
                      if (!regex.hasMatch(value)) {
                        return 'Enter a valid amount (e.g., 123 or 123.45)';
                      }

                      try {
                        final amount = double.parse(value);
                        if (amount < 0) {
                          return 'Amount cannot be negative';
                        }
                      } catch (e) {
                        return 'Enter a valid number';
                      }

                      return null;
                    },
                  ),
                  const SizedBox(height: 20),

                  // Transaction Type Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedType,
                    items: ['Income', 'Expense']
                        .map((type) => DropdownMenuItem(
                              value: type,
                              child: Text(type),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedType = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Type',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Category Dropdown
                  DropdownButtonFormField<String>(
                    value: _selectedCategory,
                    items: _categories
                        .map((category) => DropdownMenuItem(
                              value: category,
                              child: Text(category),
                            ))
                        .toList(),
                    onChanged: (value) {
                      setState(() {
                        _selectedCategory = value!;
                      });
                    },
                    decoration: const InputDecoration(
                      labelText: 'Category',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Date Picker
                  Row(
                    children: [
                      Text(
                        'Date: ${_selectedDate.toLocal()}',
                      ),
                      const Spacer(),
                      ElevatedButton(
                        onPressed: _pickDate,
                        child: const Text('Select Date'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Submit Button
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitForm,
                      child: _editorType == EditorType.edit
                          ? const Text('Update Transaction')
                          : const Text('Add Transaction'),
                    ),
                  ),

                  const SizedBox(height: 20),
                  // Delete Button (only in edit mode)
                  if (_editorType == EditorType.edit)
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.red, // Use red for delete button
                        ),
                        onPressed: _deleteTransaction,
                        child: const Text('Delete Transaction'),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  // Function to pick a date
  Future<void> _pickDate() async {
    DateTime? pickedDate = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );

    if (pickedDate != null && pickedDate != _selectedDate) {
      setState(() {
        _selectedDate = pickedDate;
      });
    }
  }

  // Function to submit the form
  void _submitForm() {
    if (_formKey.currentState!.validate()) {
      // Get the entered data
      final String title = _titleController.text;
      final double amount = double.parse(_amountController.text);
      final bool isIncome = _selectedType == 'Income';

      // Prepare the transaction object
      final transaction = Transaction(
        id: _editorType == EditorType.edit ? widget.transaction!.id : 0,
        // Preserve ID for edits
        title: title,
        amount: amount,
        isIncome: isIncome,
        category: _selectedCategory,
        date: _selectedDate,
      );

      // Save transaction to ObjectBox
      objectbox.store.box<Transaction>().putAsync(transaction);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editorType == EditorType.add_new
              ? 'Transaction added successfully!'
              : 'Transaction updated successfully!'),
        ),
      );

      // Clear the form
      _titleController.clear();
      _amountController.clear();
      setState(() {
        _selectedType = 'Income';
        _selectedCategory = 'Food';
        _selectedDate = DateTime.now();
      });

      // Save to ObjectBox or pass back
      Navigator.pop(context, transaction);
    }
  }

  void _deleteTransaction() async {
    if (widget.transaction != null) {
      // Confirm deletion
      final confirm = await showDialog<bool>(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text('Delete Transaction'),
            content: const Text('Are you sure you want to delete this transaction?'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false), // Cancel
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true), // Confirm
                child: const Text('Delete'),
              ),
            ],
          );
        },
      );

      if (confirm == true) {

        context.read<TransactionCubit>().deleteTransaction(widget.transaction!.id, widget.index!);
        //context.read<TransactionRepository>().deleteTransaction(widget.transaction!.id);
        // Remove the transaction from ObjectBox
        //objectbox.store.box<Transaction>().remove(widget.transaction!.id);

        // Show a success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Transaction deleted successfully!')),
        );

        // Navigate back to the previous screen
        Navigator.pop(context);
      }
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _amountController.dispose();
    super.dispose();
  }
}
