import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/export_to_csv.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
// import 'package:to_csv/to_csv.dart' as exportCSV;

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: Center(
        child: Column(
          children: [
            const Text('Settings Screen'),
            ElevatedButton(
              onPressed: () {
                writeToCSV(generateCSVData(
                    context.read<TransactionCubit>().state.transactions));
              },
              child: const Text("Export CSV"),
            ),
            ElevatedButton(
              onPressed: () {
                context.read<TransactionCubit>().deleteAllTransactions();
              },
              child: const Text("Delete All Transactions",
                  style: TextStyle(
                    color: Colors.white,
                  )),
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                textStyle: const TextStyle(
                  color: Colors.white,
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                String data = await readCSV();
                List<Transaction> newTransactions =
                    fromStringToTransactions(data);
                List<Transaction> existingTransactions =
                    context.read<TransactionCubit>().state.transactions;

                // Find duplicates
                List<Transaction> duplicates = newTransactions
                    .where((newTx) => existingTransactions.any((existingTx) =>
                        existingTx.amount == newTx.amount &&
                        existingTx.date == newTx.date &&
                        existingTx.title == newTx.title))
                    .toList();

                if (duplicates.isNotEmpty) {
                  // Show confirmation dialog
                  bool? shouldAdd = await showDialog<bool>(
                    context: context,
                    builder: (BuildContext dialogContext) {
                      return AlertDialog(
                        title: const Text('Duplicate Transactions Found'),
                        content: Text(
                            'Found ${duplicates.length} duplicate transactions. Do you want to add them anyway?'),
                        actions: [
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(false),
                            child: const Text('Cancel'),
                          ),
                          TextButton(
                            onPressed: () =>
                                Navigator.of(dialogContext).pop(true),
                            child: const Text('Add All'),
                          ),
                        ],
                      );
                    },
                  );

                  if (shouldAdd == true) {
                    context
                        .read<TransactionCubit>()
                        .addTransactions(newTransactions);
                  }
                } else {
                  // No duplicates found, add all transactions
                  context
                      .read<TransactionCubit>()
                      .addTransactions(newTransactions);
                }
              },
              child: const Text("Import CSV"),
            ),
          ],
        ),
      ),
    );
  }

  // void readCSV() async {
  //   String data = await readCSV();
  //   List<Transaction> transactions = fromStringToTransactions(data);
  //   context.read<TransactionCubit>().deleteTransactions();
  //   context.read<TransactionCubit>().addTransactions(transactions);
  // }
}
