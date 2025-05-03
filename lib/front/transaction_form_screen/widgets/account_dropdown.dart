import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
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

  // In AccountDropdown:
  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Account>>(
      future: Future.value(
          context.read<DataManagementCubit>().getEnabledAccountsCache()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          return Text('Error loading accounts: ${snapshot.error}',
              style: AppStyle.bodyText.copyWith(color: AppStyle.expenseColor));
        }

        final accounts = snapshot.data ?? [];

        if (accounts.isEmpty) {
          return const Text(
              'No accounts available. Please add an account first.',
              style: AppStyle.bodyText);
        }

        Account? validSelectedAccount = selectedAccount != null &&
                accounts.any((a) => a.id == selectedAccount!.id)
            ? selectedAccount
            : null;

        return DropdownButtonFormField<Account>(
          value: validSelectedAccount, // Use the validated selected account
          items: accounts.map((account) {
            return DropdownMenuItem(
              value: account,
              child: Row(
                children: [
                  Icon(
                    IconData(account.iconCodePoint,
                        fontFamily: 'MaterialIcons'),
                    color: Color(account.colorValue),
                    size: 20, // Slightly smaller icon
                  ),
                  const SizedBox(
                      width: AppStyle.paddingSmall), // Use AppStyle padding
                  Expanded(
                    // Allow text to wrap or truncate
                    child: Text(
                      account.name,
                      style: AppStyle.bodyText, // Use AppStyle
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(
                      width: AppStyle.paddingMedium), // Use AppStyle padding
                  Text(
                    // Correctly format balance and currency symbol
                    '${account.balance.toStringAsFixed(2)} ${account.currencySymbolOrCurrency}',
                    style: AppStyle.captionStyle, // Use AppStyle caption
                  ),
                ],
              ),
            );
          }).toList(),
          onChanged: onAccountChanged,
          decoration: AppStyle.getInputDecoration(
            labelText: 'Account',
          ),
          isExpanded: true, // Ensure dropdown takes full width
          selectedItemBuilder: (BuildContext context) {
            // Custom builder for selected item
            return accounts.map<Widget>((Account account) {
              return Row(
                children: <Widget>[
                  Icon(
                    IconData(account.iconCodePoint,
                        fontFamily: 'MaterialIcons'),
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
                    // Correctly format balance and currency symbol here too
                    '${account.balance.toStringAsFixed(2)} ${account.currencySymbolOrCurrency}',
                    style: AppStyle.captionStyle,
                  ),
                ],
              );
            }).toList();
          },
        );
      },
    );
  }
}
