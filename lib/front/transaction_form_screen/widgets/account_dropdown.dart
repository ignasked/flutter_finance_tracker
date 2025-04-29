import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';

class AccountDropdown extends StatelessWidget {
  final Account? selectedAccount;
  final ValueChanged<Account?> onAccountChanged;

  const AccountDropdown({
    Key? key,
    required this.selectedAccount,
    required this.onAccountChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: Future.value(context.read<AccountRepository>().getAll()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const CircularProgressIndicator();
        }

        if (snapshot.hasError) {
          return const Text('Error loading accounts');
        }

        final accounts = snapshot.data ?? [];

        return DropdownButtonFormField<Account>(
          value: selectedAccount,
          items: accounts.map((account) {
            return DropdownMenuItem(
              value: account,
              child: Row(
                children: [
                  Icon(
                    IconData(account.iconCodePoint,
                        fontFamily: 'MaterialIcons'),
                    color: Color(account.colorValue),
                  ),
                  const SizedBox(width: 8),
                  Text(account.name),
                  const SizedBox(width: 20),
                  Text('${account.balance.toString()} ${account.currency}'),
                ],
              ),
            );
          }).toList(),
          onChanged: onAccountChanged,
          decoration: const InputDecoration(
            labelText: 'Account',
            border: OutlineInputBorder(),
          ),
        );
      },
    );
  }
}
