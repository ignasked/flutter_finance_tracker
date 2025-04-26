import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';

class BulkAddTransactionsScreen extends StatefulWidget {
  final String transactionName;
  final List<Transaction> transactions;

  const BulkAddTransactionsScreen({
    Key? key,
    required this.transactionName,
    required this.transactions,
  }) : super(key: key);

  @override
  _BulkAddTransactionsScreenState createState() =>
      _BulkAddTransactionsScreenState();
}

class _BulkAddTransactionsScreenState extends State<BulkAddTransactionsScreen> {
  late double totalExpenses;

  @override
  void initState() {
    super.initState();
    print('Transaction Name: ${widget.transactionName}');
    print('Transactions: ${widget.transactions}');
    totalExpenses = _calculateTotalExpenses();
  }

  double _calculateTotalExpenses() {
    return widget.transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + transaction.amount,
    );
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
        amount: entry.value,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.transactionName),
        actions: [
          IconButton(
            icon: const Icon(Icons.merge_type),
            tooltip: 'Merge by Categories',
            onPressed: _mergeTransactionsByCategory,
          ),
        ],
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
                const SizedBox(height: 16),

                // Confirm, Cancel, and Merge buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    // Confirm button with icon
                    ElevatedButton.icon(
                      onPressed: () {
                        // Handle confirm action
                        print('Confirmed transactions');
                        Navigator.of(context).pop(widget.transactions);
                      },
                      icon: const Icon(Icons.check),
                      label: const Text(''),
                    ),

                    // Cancel button with icon
                    OutlinedButton.icon(
                      onPressed: () {
                        // Handle cancel action
                        print('Cancelled transactions');
                        Navigator.of(context).pop();
                      },
                      icon: const Icon(Icons.close),
                      label: const Text(''),
                    ),

                    // Merge by Categories button
                    ElevatedButton.icon(
                      onPressed: _mergeTransactionsByCategory,
                      icon: const Icon(Icons.merge_type),
                      label: const Text(''),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
