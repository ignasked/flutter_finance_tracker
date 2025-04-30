import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart'; // Import Account model
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_filter_widget.dart';
import 'package:money_owl/front/home_screen/widgets/transaction_summary_display.dart';

class SummaryBarWidget extends StatelessWidget {
  const SummaryBarWidget({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AccountTransactionCubit, AccountTransactionState>(
      builder: (context, state) {
        final selectedAccount = state.filters.selectedAccount;

        return Container(
          padding: const EdgeInsets.all(
              AppStyle.paddingMedium), // Use AppStyle padding
          decoration: BoxDecoration(
            color: AppStyle.cardColor, // Use AppStyle card color
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(30), // Slightly softer shadow
                blurRadius: 4,
                offset: const Offset(0, 2),
              ),
            ],
            borderRadius: BorderRadius.circular(
                AppStyle.paddingSmall), // Use AppStyle padding
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Centered Stats Section: Balance, Income, Expenses
              const TransactionSummaryDisplay(),
              const SizedBox(
                  height: AppStyle.paddingSmall), // Use AppStyle padding
              const Divider(
                  color: AppStyle.dividerColor), // Use AppStyle divider
              const SizedBox(
                  height: AppStyle.paddingSmall), // Use AppStyle padding

              // Buttons Section: Account Selector and Filter
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Account Selector
                  Flexible(
                    // Allow text to wrap or truncate if needed
                    child: Row(
                      mainAxisSize: MainAxisSize
                          .min, // Prevent row from taking full width
                      children: [
                        Icon(
                          selectedAccount != null
                              ? IconData(selectedAccount.iconCodePoint,
                                  fontFamily: 'MaterialIcons')
                              : Icons.all_inclusive,
                          color: selectedAccount != null
                              ? Color(selectedAccount.colorValue)
                              : AppStyle
                                  .textColorSecondary, // Use AppStyle color
                        ),
                        const SizedBox(
                            width:
                                AppStyle.paddingSmall), // Use AppStyle padding
                        Flexible(
                          // Allow button text to wrap/truncate
                          child: TextButton(
                            style: TextButton.styleFrom(
                              padding:
                                  EdgeInsets.zero, // Remove default padding
                              tapTargetSize: MaterialTapTargetSize
                                  .shrinkWrap, // Minimize tap area
                            ),
                            onPressed: () =>
                                _showAccountSelectionDialog(context),
                            child: Text(
                              selectedAccount?.name ?? 'All Accounts',
                              style: AppStyle.titleStyle.copyWith(
                                  color: AppStyle.primaryColor), // Use AppStyle
                              overflow:
                                  TextOverflow.ellipsis, // Handle long names
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  // Filter Button
                  IconButton(
                    icon: const Icon(Icons.filter_list,
                        color: AppStyle.primaryColor), // Use AppStyle color
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
      builder: (dialogContext) {
        // Use dialogContext to avoid conflict
        return AlertDialog(
          title: const Text('Select an Account',
              style: AppStyle.heading2), // Use AppStyle
          backgroundColor: AppStyle.cardColor, // Use AppStyle
          shape: RoundedRectangleBorder(
            borderRadius:
                BorderRadius.circular(AppStyle.paddingMedium), // Use AppStyle
          ),
          content: SizedBox(
            width: double.maxFinite,
            child: ListView.builder(
              shrinkWrap: true,
              itemCount: accounts.length + 1, // Include "All Accounts" option
              itemBuilder: (context, index) {
                if (index == 0) {
                  // "All Accounts" Option
                  return ListTile(
                    leading: const Icon(Icons.all_inclusive,
                        color: AppStyle.textColorSecondary), // Use AppStyle
                    title: const Text('All Accounts',
                        style: AppStyle.bodyText), // Use AppStyle
                    onTap: () {
                      accountTransactionCubit.changeSelectedAccount(null);
                      Navigator.pop(dialogContext); // Close the dialog
                    },
                  );
                }

                // Specific Account Option
                final account = accounts[index - 1];
                return ListTile(
                  leading: Icon(
                    IconData(account.iconCodePoint,
                        fontFamily: 'MaterialIcons'),
                    color: Color(account.colorValue),
                  ),
                  title: Text(account.name,
                      style: AppStyle.bodyText), // Use AppStyle
                  onTap: () {
                    accountTransactionCubit.changeSelectedAccount(account);
                    Navigator.pop(dialogContext); // Close the dialog
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: const Text('Cancel',
                  style:
                      TextStyle(color: AppStyle.primaryColor)), // Use AppStyle
            ),
          ],
        );
      },
    );
  }
}
