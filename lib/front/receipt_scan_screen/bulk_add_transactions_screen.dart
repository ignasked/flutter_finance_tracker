import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';

class BulkAddTransactionsScreen extends StatefulWidget {
  final String transactionName;
  final DateTime date;
  final double totalExpensesFromReceipt;
  final List<Transaction> transactions;

  const BulkAddTransactionsScreen({
    Key? key,
    required this.transactionName,
    required this.date,
    required this.totalExpensesFromReceipt,
    required this.transactions,
  }) : super(key: key);

  @override
  _BulkAddTransactionsScreenState createState() =>
      _BulkAddTransactionsScreenState();
}

class _BulkAddTransactionsScreenState extends State<BulkAddTransactionsScreen> {
  late double totalExpenses;
  Account? selectedAccount;
  String? warningMessage;

  @override
  void initState() {
    super.initState();
    print('Transaction Name: ${widget.transactionName}');
    print('Transactions: ${widget.transactions}');
    selectedAccount = Defaults().defaultAccount;
    totalExpenses = _calculateTotalExpenses();

    // Check if totalExpensesFromReceipt matches calculated totalExpenses
    if (widget.totalExpensesFromReceipt != totalExpenses) {
      warningMessage =
          'Check the transactions.\n Total expenses should be: ${widget.totalExpensesFromReceipt?.toStringAsFixed(2)}';
    }
  }

  double _calculateTotalExpenses() {
    final totalExpenses = widget.transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );

    if (totalExpenses != widget.totalExpensesFromReceipt) {
      warningMessage =
          'Check the transactions.\n Total expenses should be: ${widget.totalExpensesFromReceipt?.toStringAsFixed(2)}';
    } else {
      warningMessage = null; // Clear warning if they match
    }
    return totalExpenses;
  }

  void _removeTransaction(int index) {
    setState(() {
      widget.transactions.removeAt(index);
      totalExpenses = _calculateTotalExpenses(); // Recalculate total expenses
    });
  }

  void _mergeTransactionsByCategory() {
    // Group transactions by category
    final Map<int, double> categoryTotals = {};
    for (var transaction in widget.transactions) {
      final category = transaction.category.target;
      if (category != null) {
        if (categoryTotals.containsKey(category.id)) {
          categoryTotals[category.id] =
              categoryTotals[category.id]! + transaction.amount;
        } else {
          categoryTotals[category.id] = transaction.amount;
        }
      }
    }

    // Create a new list of merged transactions
    final mergedTransactions = categoryTotals.entries.map((entry) {
      final category = widget.transactions
          .firstWhere(
              (transaction) => transaction.category.target?.id == entry.key)
          .category
          .target;

      return Transaction(
        title:
            '${category?.title} at ${widget.transactionName}', // Optional: Add a prefix to indicate merging
        category: category,
        amount: double.parse(entry.value.toStringAsFixed(2)),
        date: DateTime.now(), // Use the current date or a default date
      );
    }).toList();

    // Update the state with the merged transactions
    setState(() {
      widget.transactions
        ..clear()
        ..addAll(mergedTransactions);
      totalExpenses = _calculateTotalExpenses(); // Recalculate total expenses
    });

    print('Transactions merged by category: $mergedTransactions');
  }

  void _applyAccountToAllTransactions(Account account) {
    setState(() {
      for (var transaction in widget.transactions) {
        transaction.account.target =
            account; // Assuming Transaction has an 'account' field
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '${widget.transactionName} | ${DateFormat("yMMMd").format(widget.date)}'),
      ),
      body: Column(
        children: [
          // Scrollable list of transactions
          Flexible(
            child: ListView.builder(
              itemCount: widget.transactions.length,
              itemBuilder: (context, index) {
                final transaction = widget.transactions[index];
                final category = transaction.category.target;

                return Dismissible(
                  key: UniqueKey(),
                  confirmDismiss: (direction) async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (BuildContext context) {
                        return AlertDialog(
                          title: const Text('Confirm'),
                          content:
                              const Text('Are you sure you want to delete?'),
                          actions: <Widget>[
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(false),
                              child: const Text('No'),
                            ),
                            TextButton(
                              onPressed: () => Navigator.of(context).pop(true),
                              child: const Text('Yes'),
                            ),
                          ],
                        );
                      },
                    );

                    return result ?? false;
                  },
                  onDismissed: (direction) {
                    _removeTransaction(
                        index); // Remove transaction and recalculate total
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('${transaction.title} deleted.'),
                      ),
                    );
                  },
                  background: Container(
                    color: Colors.red,
                    padding: const EdgeInsets.only(right: 20),
                    alignment: Alignment.centerRight,
                    child: const Icon(
                      Icons.delete,
                      color: Colors.white,
                    ),
                  ),
                  child: Card(
                    child: ListTile(
                      leading: Icon(
                        category?.icon ?? Icons.category,
                        color: Color(category?.colorValue ?? 0xFF000000),
                      ),
                      title: Text(transaction.title),
                      subtitle: Text(
                          'Price: ${transaction.amount.toStringAsFixed(2)}. Category: ${category?.title ?? 'Uncategorized'}'),
                      trailing: const Icon(Icons.edit),
                      onTap: () async {
                        // Navigate to TransactionFormScreen to edit the transaction
                        final transactionResult =
                            await Navigator.push<TransactionResult?>(
                          context,
                          MaterialPageRoute(
                            builder: (context) => TransactionFromScreen(
                              transaction: transaction,
                              index: index,
                            ),
                          ),
                        );

                        // If a TransactionResult is returned, update the list
                        if (transactionResult != null) {
                          setState(() {
                            widget.transactions[transactionResult.index!] =
                                transactionResult.transaction;
                            totalExpenses =
                                _calculateTotalExpenses(); // Recalculate total
                          });
                        }
                      },
                    ),
                  ),
                );
              },
            ),
          ),

          // Footer with total expenses and buttons
          Container(
            color: Colors.white,
            padding: const EdgeInsets.all(16.0),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Total expenses
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text(
                      'Total Expenses:',
                      style:
                          TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      '${totalExpenses.toStringAsFixed(2)}',
                      style: const TextStyle(
                          fontSize: 16, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),

                // Warning message
                if (warningMessage != null)
                  Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Row(
                        children: [
                          Icon(
                            Icons.warning,
                            color: Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            warningMessage!,
                            style: const TextStyle(
                              color: Colors.orange,
                              fontSize: 14,
                            ),
                          ),
                        ],
                      )),

                const SizedBox(height: 16),

                // Account dropdown
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8.0),
                  child: AccountDropdown(
                    selectedAccount: selectedAccount,
                    onAccountChanged: (account) {
                      setState(() {
                        selectedAccount = account;
                        _applyAccountToAllTransactions(account!);
                      });
                    },
                  ),
                ),

                // Buttons row
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16.0),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      OutlinedButton.icon(
                        onPressed: () {
                          print('Cancelled transactions');
                          Navigator.of(context).pop();
                        },
                        style: OutlinedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(Icons.close),
                        label: const Text('Cancel'),
                      ),
                      ElevatedButton.icon(
                        onPressed: _mergeTransactionsByCategory,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.blue,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(
                          Icons.merge_type,
                          color: Colors.white,
                        ),
                        label: const Text('Merge',
                            style: TextStyle(color: Colors.white)),
                      ),
                      ElevatedButton.icon(
                        onPressed: () {
                          print('Confirmed transactions');
                          Navigator.of(context).pop(widget.transactions);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.green,
                          padding: const EdgeInsets.symmetric(
                              horizontal: 24, vertical: 12),
                        ),
                        icon: const Icon(
                          Icons.check,
                          color: Colors.white,
                        ),
                        label: const Text('Save',
                            style: TextStyle(color: Colors.white)),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
