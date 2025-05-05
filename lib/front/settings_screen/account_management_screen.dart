import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/settings_screen/widgets/account_form_widget.dart';

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DataManagementCubit, DataManagementState>(
      builder: (context, dataState) {
        final accounts = dataState.allAccounts;
        final dataManagementCubit = context.read<DataManagementCubit>();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Manage Accounts'),
            bottom: dataState.status == LoadingStatus.loading
                ? const PreferredSize(
                    preferredSize: Size.fromHeight(4.0),
                    child: LinearProgressIndicator(),
                  )
                : null,
          ),
          body: ListView.builder(
            itemCount: accounts.length,
            itemBuilder: (context, index) {
              final account = accounts[index];
              final bool isDefaultCashAccount =
                  account.id == 2 || account.id == 1;
              final bool hasTransactions =
                  dataManagementCubit.hasTransactionsForAccount(account.id);
              final bool canDelete = !isDefaultCashAccount && !hasTransactions;

              return ListTile(
                leading: Icon(
                  IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
                  color: Color(account.colorValue),
                ),
                title: Text(account.name),
                subtitle: Text(account.currency),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.edit),
                      tooltip: 'Edit Account',
                      onPressed: () async {
                        final updatedAccount = await showDialog<Account?>(
                          context: context,
                          builder: (_) =>
                              AccountFormWidget(initialAccount: account),
                        );

                        if (updatedAccount != null) {
                          dataManagementCubit.updateAccount(updatedAccount);
                        }
                      },
                    ),
                    IconButton(
                      icon: const Icon(Icons.delete),
                      tooltip: canDelete
                          ? 'Delete Account'
                          : (isDefaultCashAccount
                              ? 'Cannot delete default Cash account'
                              : 'Cannot delete account with transactions'),
                      color: canDelete ? null : Theme.of(context).disabledColor,
                      onPressed: canDelete
                          ? () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (context) => AlertDialog(
                                  title: const Text('Delete Account'),
                                  content: Text(
                                      'Are you sure you want to delete the account "${account.name}"? This cannot be undone.'),
                                  actions: [
                                    TextButton(
                                      onPressed: () =>
                                          Navigator.pop(context, false),
                                      child: const Text('Cancel'),
                                    ),
                                    TextButton(
                                      style: TextButton.styleFrom(
                                          foregroundColor: Colors.red),
                                      onPressed: () =>
                                          Navigator.pop(context, true),
                                      child: const Text('Delete'),
                                    ),
                                  ],
                                ),
                              );

                              if (confirm == true) {
                                dataManagementCubit.deleteAccount(account.id);
                              }
                            }
                          : null,
                    ),
                    Switch(
                      value: account.isEnabled,
                      onChanged: (value) {
                        final toggledAccount =
                            account.copyWith(isEnabled: value);
                        dataManagementCubit.updateAccount(toggledAccount);
                      },
                    ),
                  ],
                ),
              );
            },
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () async {
              final newAccount = await showDialog<Account?>(
                context: context,
                builder: (_) => BlocProvider.value(
                  value: dataManagementCubit,
                  child: const AccountFormWidget(),
                ),
              );

              if (newAccount != null) {
                dataManagementCubit.addAccount(newAccount);
              }
            },
            tooltip: 'Add Account',
            child: const Icon(Icons.add),
          ),
        );
      },
    );
  }
}
