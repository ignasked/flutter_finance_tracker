import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/front/add_transaction_screen/add_transaction_screen.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';

class TransactionList extends StatelessWidget {
  const TransactionList({
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TransactionCubit, TransactionState>(
      builder: (context, state) {
        return ListView.builder(
          itemCount: state.transactions.length,
          itemBuilder: (context, index) {
            return Card(
              child: ListTile(
                leading: Icon(
                  state.transactions[index].isIncome
                      ? Icons.arrow_upward
                      : Icons.arrow_downward,
                  color: state.transactions[index].isIncome
                      ? Colors.green
                      : Colors.red,
                ),
                title: Text(state.transactions[index].title),
                subtitle: Text(
                  '${state.transactions[index].category} | ${state.transactions[index].date.toString().split(' ')[0]}',
                ),
                trailing: Text(
                  '${state.transactions[index].isIncome ? '+' : '-'} \$${state.transactions[index].amount.toStringAsFixed(2)}',
                  style: TextStyle(
                    color: state.transactions[index].isIncome
                        ? Colors.green
                        : Colors.red,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                onTap: () async {
                  final updatedTransaction = await Navigator.push<Transaction>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => AddTransactionScreen(
                        transaction: state.transactions[index],
                        index: index,
                      ),
                    ),
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}
