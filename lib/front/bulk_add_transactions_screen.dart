import 'package:flutter/material.dart';

class BulkAddTransactionsScreen extends StatefulWidget {
  final Map<String, dynamic> transactionData;

  const BulkAddTransactionsScreen({Key? key, required this.transactionData})
      : super(key: key);

  @override
  _BulkAddTransactionsScreenState createState() =>
      _BulkAddTransactionsScreenState();
}

class _BulkAddTransactionsScreenState extends State<BulkAddTransactionsScreen> {
  late List<dynamic> transactions;
  late double totalExpenses;

  @override
  void initState() {
    super.initState();
    // Initialize transactions and calculate total expenses
    transactions = widget.transactionData['transactions'] as List<dynamic>;
    totalExpenses = _calculateTotalExpenses();
  }

  double _calculateTotalExpenses() {
    return transactions.fold<double>(
      0.0,
      (sum, transaction) => sum + (transaction['price'] ?? 0.0),
    );
  }

  void _removeTransaction(int index) {
    setState(() {
      transactions.removeAt(index);
      totalExpenses = _calculateTotalExpenses(); // Recalculate total expenses
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title:
            Text(widget.transactionData['transactionName'] ?? 'Transactions'),
      ),
      body: Column(
        children: [
          // Scrollable list of transactions
          Flexible(
            child: ListView.builder(
              itemCount: transactions.length,
              itemBuilder: (context, index) {
                final transaction = transactions[index];

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
                        content: Text('${transaction['name']} deleted.'),
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
                        Icons.receipt_long,
                        color: Colors.blue,
                      ),
                      title: Text(
                          transaction['description'] ?? 'Unnamed Transaction'),
                      subtitle: Text(
                          'Price: ${transaction['price'] ?? 'N/A'}. ${transaction['category'] ?? 'N/A'}'),
                      trailing: Icon(Icons.edit),
                      onTap: () {
                        // Handle editing later
                        print('Tapped on transaction: ${transaction['name']}');
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

                // Confirm and Cancel buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    ElevatedButton(
                      onPressed: () {
                        // Handle confirm action
                        print('Confirmed transactions');
                        Navigator.of(context).pop(); // Close the screen
                      },
                      child: const Text('Confirm'),
                    ),
                    OutlinedButton(
                      onPressed: () {
                        // Handle cancel action
                        print('Cancelled transactions');
                        Navigator.of(context).pop(); // Close the screen
                      },
                      child: const Text('Cancel'),
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
