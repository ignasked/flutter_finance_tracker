import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_filter_widget.dart';

class SummaryBarWidget extends StatelessWidget {
  const SummaryBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountTransactionCubit, AccountTransactionState>(
      builder: (context, state) {
        final selectedAccount = state.filters.selectedAccount;

        return Container(
          padding: const EdgeInsets.all(14.0),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(40),
                blurRadius: 3,
                offset: const Offset(0, 3),
              ),
            ],
            borderRadius: BorderRadius.circular(8.0),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Centered Stats Section: Balance, Income, Expenses
              Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Text(
                    '\$${state.balance.toStringAsFixed(2)}',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                    textAlign: TextAlign.center,
                  ),
                  const SizedBox(height: 4),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        '\$${state.totalIncome.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.green,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Text(
                        '\$${state.totalExpenses.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.bold,
                          color: Colors.red,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              // Buttons Section: Account Selector and Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Account Selector
                  Row(
                    children: [
                      Icon(
                        selectedAccount != null
                            ? IconData(selectedAccount.iconCodePoint,
                                fontFamily: 'MaterialIcons')
                            : Icons.all_inclusive,
                        color: selectedAccount != null
                            ? Color(selectedAccount.colorValue)
                            : Colors.grey,
                      ),
                      const SizedBox(width: 8),
                      TextButton(
                        onPressed: () => _showAccountSelectionDialog(context),
                        child: Text(
                          selectedAccount?.name ?? 'All Accounts',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                            color: Colors.blue,
                          ),
                        ),
                      ),
                    ],
                  ),

                  // Filter Button
                  IconButton(
                    icon: const Icon(Icons.filter_list, color: Colors.blue),
                    onPressed: () => TransactionFilterSheet.show(context),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  /// Show a dialog to select an account
  void _showAccountSelectionDialog(BuildContext context) {
    final accountTransactionCubit = context.read<AccountTransactionCubit>();
    final accounts = accountTransactionCubit.state.allAccounts;

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Select an Account'),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length + 1, // Include "All Accounts" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  return ListTile(
                    leading: const Icon(Icons.all_inclusive),
                    title: const Text('All Accounts'),
                    onTap: () {
                      accountTransactionCubit.changeSelectedAccount(null);
                      Navigator.pop(context); // Close the dialog
                    },
                  );
                }

                final account = accounts[index - 1];
                return ListTile(
                  leading: Icon(
                    IconData(account.iconCodePoint,
                        fontFamily: 'MaterialIcons'),
                    color: Color(account.colorValue),
                  ),
                  title: Text(account.name),
                  onTap: () {
                    accountTransactionCubit.changeSelectedAccount(account);
                    Navigator.pop(context); // Close the dialog
                  },
                );
              },
            ),
          ),
        );
      },
    );
  }
}
