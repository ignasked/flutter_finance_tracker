import 'package:flutter/material.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/utils/currency_utils.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
import 'package:money_owl/backend/utils/app_style.dart';

class AccountFormWidget extends StatefulWidget {
  final Account? initialAccount;

  const AccountFormWidget({this.initialAccount, Key? key}) : super(key: key);

  @override
  _AccountFormWidgetState createState() => _AccountFormWidgetState();
}

class _AccountFormWidgetState extends State<AccountFormWidget> {
  late TextEditingController _nameController;
  late TextEditingController _balanceController;
  late Account _accountState;

  @override
  void initState() {
    super.initState();
    // Initialize the state with a copy of the initial account or a new account
    _accountState = widget.initialAccount?.copyWith() ??
        Account(
          name: '',
          typeValue: AccountType.bank.index,
          currency: Defaults().defaultCurrency,
          currencySymbol:
              CurrencyUtils.predefinedCurrencies[Defaults().defaultCurrency] ??
                  Defaults().defaultCurrency,
          balance: 0.0,
          colorValue: AppStyle.predefinedColors.first.value,
          iconCodePoint: AppStyle.predefinedIcons.first.codePoint,
        );

    _nameController = TextEditingController(text: _accountState.name);
    _balanceController =
        TextEditingController(text: _accountState.balance.toString());
  }

  @override
  void dispose() {
    _nameController.dispose();
    _balanceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title:
          Text(widget.initialAccount == null ? 'Add Account' : 'Edit Account'),
      content: Form(
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Name'),
                onChanged: (value) => setState(() {
                  _accountState = _accountState.copyWith(name: value);
                }),
              ),
              DropdownButtonFormField<AccountType>(
                value: AccountType.values[_accountState.typeValue],
                decoration: const InputDecoration(labelText: 'Type'),
                items: AccountType.values
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _accountState =
                      _accountState.copyWith(typeValue: value!.index);
                }),
              ),
              DropdownButtonFormField<Color>(
                value: AppStyle.predefinedColors
                        .contains(Color(_accountState.colorValue))
                    ? Color(_accountState.colorValue)
                    : AppStyle.predefinedColors.first,
                decoration: const InputDecoration(labelText: 'Color'),
                items: AppStyle.predefinedColors
                    .map((color) => DropdownMenuItem(
                          value: color,
                          child: Container(
                            width: 24,
                            height: 24,
                            color: color,
                          ),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _accountState =
                      _accountState.copyWith(colorValue: value?.value);
                }),
              ),
              DropdownButtonFormField<IconData>(
                value: IconData(_accountState.iconCodePoint,
                    fontFamily: 'MaterialIcons'),
                decoration: const InputDecoration(labelText: 'Icon'),
                items: AppStyle.predefinedIcons
                    .map((icon) => DropdownMenuItem(
                          value: icon,
                          child: Icon(icon),
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _accountState =
                      _accountState.copyWith(iconCodePoint: value!.codePoint);
                }),
              ),
              DropdownButtonFormField<String>(
                value: CurrencyUtils.predefinedCurrencies.keys
                        .contains(_accountState.currency)
                    ? _accountState.currency
                    : CurrencyUtils.predefinedCurrencies.keys.first,
                decoration: const InputDecoration(labelText: 'Currency'),
                items: CurrencyUtils.predefinedCurrencies.entries
                    .map((entry) => DropdownMenuItem(
                          value: entry.key,
                          child: Text(
                              '${entry.key} (${entry.value})'), // Display code and symbol
                        ))
                    .toList(),
                onChanged: (value) => setState(() {
                  _accountState = _accountState.copyWith(
                      currency: value,
                      currencySymbol:
                          CurrencyUtils.predefinedCurrencies[value] ??
                              Defaults().defaultCurrency);
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.pop(context, _accountState);
          },
          child: const Text('Save'),
        ),
      ],
    );
  }
}
