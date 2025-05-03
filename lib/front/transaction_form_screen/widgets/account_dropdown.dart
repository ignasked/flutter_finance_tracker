import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart'; // Import AppStyle

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
    final accounts =
        context.read<DataManagementCubit>().getEnabledAccountsCache();

    if (accounts.isEmpty) {
      return const Text('No accounts available. Please add an account first.',
          style: AppStyle.bodyText);
    }

    Account? validSelectedAccount = selectedAccount != null &&
            accounts.any((a) => a.id == selectedAccount!.id)
        ? selectedAccount
        : null;

    return DropdownButtonFormField<Account>(
      value: validSelectedAccount,
      items: accounts.map((account) {
        return DropdownMenuItem(
          value: account,
          child: Row(
            children: [
              Icon(
                IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Color(account.colorValue),
                size: 20,
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: Text(
                  account.name,
                  style: AppStyle.bodyText,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppStyle.paddingMedium),
              Text(
                '${account.balance.toStringAsFixed(2)} ${account.currencySymbolOrCurrency}',
                style: AppStyle.captionStyle,
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onAccountChanged,
      decoration: AppStyle.getInputDecoration(
        labelText: 'Account',
      ),
      isExpanded: true,
      selectedItemBuilder: (BuildContext context) {
        return accounts.map<Widget>((Account account) {
          return Row(
            children: <Widget>[
              Icon(
                IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Color(account.colorValue),
                size: 20,
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: Text(
                  account.name,
                  style: AppStyle.bodyText,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              Text(
                '${account.balance.toStringAsFixed(2)} ${account.currencySymbolOrCurrency}',
                style: AppStyle.captionStyle,
              ),
            ],
          );
        }).toList();
      },
    );
  }
}
