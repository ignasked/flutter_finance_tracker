import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:formz/formz.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/cubit/transaction_form_cubit.dart';

import 'package:pvp_projektas/main.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';
import 'package:pvp_projektas/front/add_transaction_screen/add_transaction_screen.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';

import 'package:pvp_projektas/front/home_screen/widgets/transaction_list.dart';
import 'package:pvp_projektas/front/home_screen/widgets/transaction_summary.dart';

/*class HomeScreen extends StatefulWidget {
  const HomeScreen({Key? key}) : super(key: key);

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}*/

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transactions'),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: BlocBuilder<TransactionCubit, TransactionState>(
            builder: (context, state) {
              if (state.transactions.isEmpty) {
                return const Center(child: Text('No transactions.'));
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    flex: 1,
                    child: TransactionSummary(transactions: state.transactions),
                  ),
                  const SizedBox(height: 2),
                  Expanded(
                    flex: 6,
                    child: TransactionList(transactions: state.transactions),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () async { final TransactionResult? transactionFormResult =
         await Navigator.push<TransactionResult>(
            context,
            MaterialPageRoute(
              builder: (context) => const AddTransactionScreen(),
            ),
          );

          if (transactionFormResult != null) {

            context.read<TransactionCubit>().handleTransactionFormResult(transactionFormResult);
          }
        },
        child: const Icon(Icons.add),
      ),
    );
  }
}
