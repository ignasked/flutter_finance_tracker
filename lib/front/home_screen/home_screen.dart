import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/bloc/transaction_cubit.dart';
import 'package:pvp_projektas/models/Transaction.dart';
import 'package:pvp_projektas/main.dart';
import 'package:pvp_projektas/screens/AddTransactionScreen.dart';
import 'package:pvp_projektas/widgets/TransactionList.dart';
import 'package:pvp_projektas/widgets/TransactionSummary.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    super.initState();
  }


  @override
  void dispose() {
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: BlocBuilder<TransactionCubit, List<Transaction>>(
            builder: (context, transactions) {
              if (transactions.isEmpty) {
                return const Center(child: Text('Empty.'));
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TransactionSummary(transactions: transactions),
                  const SizedBox(height: 10),
                  Expanded(
                    child: TransactionList(
                      transactions: transactions,
                      onUpdate: (updatedTransaction, index) {
                        context
                            .read<TransactionCubit>()
                            .updateTransaction(updatedTransaction);
                      },
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async {
          final newTransaction = await Navigator.push<Transaction>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );

          if (newTransaction != null) {
            context.read<TransactionCubit>().addTransaction(newTransaction);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
