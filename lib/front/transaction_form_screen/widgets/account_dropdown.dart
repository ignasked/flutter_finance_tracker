import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/utils/app_style.dart';

class AccountDropdown extends StatelessWidget {
  final Account? selectedAccount;
  final ValueChanged<Account?> onChanged;
  final List<Account> accounts;

  const AccountDropdown({
    super.key,
    required this.selectedAccount,
    required this.onChanged,
    required this.accounts,
  });

  @override
  Widget build(BuildContext context) {
    if (accounts.isEmpty) {
      return const Text('No accounts available.', style: AppStyle.bodyText);
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
                '${account.currencySymbolOrCurrency}',
                style: AppStyle.captionStyle,
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: onChanged,
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
                '${account.currencySymbolOrCurrency}',
                style: AppStyle.captionStyle,
              ),
            ],
          );
        }).toList();
      },
    );
  }
}
