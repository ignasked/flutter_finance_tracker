import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';
import 'package:money_owl/front/settings_screen/widgets/account_form_widget.dart';
import 'package:path/path.dart';

class AccountCubit extends Cubit<List<Account>> {
  final AccountRepository _accRepo;
  final TransactionRepository _txRepo;
  final TransactionsCubit _txCubit;

  AccountCubit(this._accRepo, this._txCubit, this._txRepo) : super([]) {
    loadAccounts();
  }

  void loadAccounts() async {
    final accounts = await _accRepo.getAll();
    emit(accounts);
  }

  void toggleAccount(Account account, bool isEnabled) {
    final updatedAccount = account.copyWith(isEnabled: isEnabled);
    _accRepo.put(updatedAccount);
    final updatedAccounts =
        state.map((a) => a.id == account.id ? updatedAccount : a).toList();
    emit(updatedAccounts);
  }

  void addAccount(Account account) {
    _accRepo.put(account);
    emit([...state, account]);
  }

  void editAccount(Account account) {
    _accRepo.put(account);

    final index = state.indexWhere((a) => a.id == account.id);
    if (index != -1) {
      state[index] = account; // Directly update the account in the state list
    }

    _txCubit.state.allAccounts[
            _txCubit.state.allAccounts.indexWhere((a) => a.id == account.id)] =
        account; // Update the account in the transaction cubit

    Defaults().defaultAccount = account;
    // _txCubit.loadAccounts(); // force reload
    // _txCubit.loadAllTransactions(); // force reload
    // _txCubit.resetFilters();

    emit([...state]);
  }

  void deleteAccount(Account account) {
    _accRepo.remove(account.id);
    emit(state.where((a) => a.id != account.id).toList());
  }

  Future<bool> isAccountRemovable(Account account) async {
    // Check if the account has related transactions
    return await _txRepo.hasTransactionsForAccount(account.id) ||
        account.id == 2;
  }
}

class AccountManagementScreen extends StatelessWidget {
  const AccountManagementScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => AccountCubit(
          context.read<AccountRepository>(),
          context.read<TransactionsCubit>(),
          context.read<TransactionRepository>()),
      child: BlocBuilder<AccountCubit, List<Account>>(
        builder: (context, accounts) {
          return Scaffold(
            appBar: AppBar(
              title: const Text('Manage Accounts'),
            ),
            body: ListView.builder(
              itemCount: accounts.length,
              itemBuilder: (context, index) {
                final account = accounts[index];

                return FutureBuilder<bool>(
                  future:
                      context.read<AccountCubit>().isAccountRemovable(account),
                  builder: (context, snapshot) {
                    // Show loading indicator while waiting
                    if (snapshot.connectionState == ConnectionState.waiting) {
                      return ListTile(
                        leading: Icon(
                          IconData(account.iconCodePoint,
                              fontFamily: 'MaterialIcons'),
                          color: Color(account.colorValue),
                        ),
                        title: Text(account.name),
                        subtitle: Text(account.currency),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                                icon: const Icon(Icons.edit),
                                onPressed: () async {
                                  final updatedAccount =
                                      await showDialog<Account?>(
                                    context: context,
                                    builder: (context) => AccountFormWidget(
                                        initialAccount: account),
                                  );

                                  if (updatedAccount != null) {
                                    context
                                        .read<AccountCubit>()
                                        .editAccount(updatedAccount);
                                  }
                                }),
                            const IconButton(
                              icon: SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              ),
                              onPressed: null, // Disabled while loading
                            ),
                            Switch(
                              value: account.isEnabled,
                              onChanged: (value) => context
                                  .read<AccountCubit>()
                                  .toggleAccount(account, value),
                            ),
                          ],
                        ),
                      );
                    }

                    // Future completed, use the result
                    final canDelete = snapshot.hasData && !snapshot.data!;

                    return ListTile(
                      leading: Icon(
                        IconData(account.iconCodePoint,
                            fontFamily: 'MaterialIcons'),
                        color: Color(account.colorValue),
                      ),
                      title: Text(account.name),
                      subtitle: Text(account.currency),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Edit button
                          IconButton(
                            icon: const Icon(Icons.edit),
                            onPressed: () async {
                              final updatedAccount = await showDialog<Account?>(
                                context: context,
                                builder: (context) =>
                                    AccountFormWidget(initialAccount: account),
                              );

                              if (updatedAccount != null) {
                                context
                                    .read<AccountCubit>()
                                    .editAccount(updatedAccount);
                              }
                            },
                          ),
                          // Delete button
                          IconButton(
                            icon: const Icon(Icons.delete),
                            onPressed: canDelete
                                ? () async {
                                    final confirm = await showDialog<bool>(
                                      context: context,
                                      builder: (context) => AlertDialog(
                                        title: const Text('Delete Account'),
                                        content: Text(
                                            'Are you sure you want to delete the account "${account.name}"?'),
                                        actions: [
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, false),
                                            child: const Text('Cancel'),
                                          ),
                                          TextButton(
                                            onPressed: () =>
                                                Navigator.pop(context, true),
                                            child: const Text('Delete'),
                                          ),
                                        ],
                                      ),
                                    );

                                    if (confirm == true) {
                                      context
                                          .read<AccountCubit>()
                                          .deleteAccount(account);
                                    }
                                  }
                                : null, // Disable the button if the account has transactions
                          ),
                          Switch(
                            value: account.isEnabled,
                            onChanged: (value) => context
                                .read<AccountCubit>()
                                .toggleAccount(account, value),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
            floatingActionButton: FloatingActionButton(
              onPressed: () async {
                final newAccount = await showDialog<Account?>(
                  context: context,
                  builder: (context) => const AccountFormWidget(),
                );

                if (newAccount != null) {
                  context.read<AccountCubit>().addAccount(newAccount);
                }
              },
              tooltip: 'Add Account',
              child: const Icon(Icons.add),
            ),
          );
        },
      ),
    );
  }
}
