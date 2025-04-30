import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle

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
    // Reintroduce FutureBuilder to handle potential async loading
    return FutureBuilder<List<Account>>(
      // Assuming getAllEnabled might still be async or needs time
      future: Future.value(context.read<AccountRepository>().getAllEnabled()),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          // Show a loading indicator while waiting
          return const Center(child: CircularProgressIndicator());
        }

        if (snapshot.hasError) {
          // Show an error message if loading failed
          return Text('Error loading accounts: ${snapshot.error}',
              style: AppStyle.bodyText.copyWith(color: AppStyle.expenseColor));
        }

        final accounts = snapshot.data ?? [];

        if (accounts.isEmpty) {
          return const Text(
              'No accounts available. Please add an account first.',
              style: AppStyle.bodyText);
        }

        // Ensure the selectedAccount is actually in the list of items
        Account? validSelectedAccount = selectedAccount != null &&
                accounts.any((a) => a.id == selectedAccount!.id)
            ? selectedAccount
            : null;
        // If the previously selected account is no longer enabled/available,
        // potentially default to the first account or null
        if (selectedAccount != null &&
            validSelectedAccount == null &&
            accounts.isNotEmpty) {
          // Optionally call onAccountChanged(null) or onAccountChanged(accounts.first) here
          // depending on desired behavior when the selected item disappears.
          // For now, we just ensure the Dropdown doesn't crash by setting value to null.
        }

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
          decoration: const InputDecoration(
            labelText: 'Account',
            labelStyle: AppStyle.bodyText, // Use AppStyle
            border: OutlineInputBorder(),
            // Add focused border style for consistency
            focusedBorder: OutlineInputBorder(
              borderSide: BorderSide(color: AppStyle.primaryColor, width: 2.0),
            ),
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
