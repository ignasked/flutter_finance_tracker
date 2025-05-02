import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/receipt_scan/bulk_add/cubit/bulk_transactions_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';

/// Screen for reviewing and adding transactions from a receipt scan.
/// Allows users to modify, merge, or apply discounts to transactions
/// before saving them to the app.
class BulkAddTransactionsScreen extends StatelessWidget {
  final String transactionName;
  final DateTime date;
  final double totalExpensesFromReceipt;
  final List<Transaction> transactions;

  const BulkAddTransactionsScreen({
    Key? key,
    required this.transactionName,
    required this.date,
    required this.totalExpensesFromReceipt,
    required this.transactions,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BulkTransactionsCubit(
        transactions: transactions,
        storeName: transactionName,
        receiptDate: date,
        receiptTotalAmount: totalExpensesFromReceipt,
      ),
      child: const _BulkAddTransactionsView(),
    );
  }
}

/// Main view for the BulkAddTransactionsScreen
class _BulkAddTransactionsView extends StatelessWidget {
  const _BulkAddTransactionsView({super.key});

  @override
  Widget build(BuildContext context) {
    // Get total height and padding for calculations if needed, but often flex handles it
    // final screenHeight = MediaQuery.of(context).size.height;
    // final appBarHeight = AppBar().preferredSize.height;
    // final statusBarHeight = MediaQuery.of(context).padding.top;

    return Scaffold(
      backgroundColor: AppStyle.backgroundColor,
      appBar: AppBar(
        title: const Text('Review Receipt Items'),
        backgroundColor: AppStyle.primaryColor,
        foregroundColor: ColorPalette.onPrimary,
        elevation: AppStyle.elevationSmall,
        iconTheme: const IconThemeData(color: ColorPalette.onPrimary),
        actions: [
          // Optional: Add item count directly in AppBar?
          BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
            buildWhen: (p, c) => p.transactions.length != c.transactions.length,
            builder: (context, state) {
              if (state.transactions.isNotEmpty) {
                return Padding(
                  padding: const EdgeInsets.only(right: AppStyle.paddingMedium),
                  child: Center(
                    child: Text(
                      '${state.transactions.length} Items',
                      style: AppStyle.captionStyle
                          .copyWith(color: ColorPalette.onPrimary),
                    ),
                  ),
                );
              }
              return const SizedBox.shrink();
            },
          )
        ],
      ),
      // Body structure: List fills space above the bottom panel
      body: Column(
        children: [
          // Transactions List takes all available space
          Expanded(
            child: BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
              buildWhen: (previous, current) =>
                  previous.transactions.hashCode !=
                  current.transactions.hashCode,
              builder: (context, state) {
                if (state.transactions.isEmpty) {
                  return const _EmptyTransactionsList(); // Styled empty state
                } else {
                  return ListView.separated(
                    itemCount: state.transactions.length,
                    // Add padding at the top/bottom of the list itself
                    padding: const EdgeInsets.symmetric(
                        vertical: AppStyle.paddingMedium),
                    itemBuilder: (context, index) {
                      // Horizontal padding inside item for dismissible background
                      return Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: AppStyle.paddingMedium),
                        child: _TransactionListItem(
                          transaction: state.transactions[index],
                          index: index,
                        ),
                      );
                    },
                    separatorBuilder: (context, index) => Divider(
                      height: AppStyle.paddingSmall,
                      thickness: 1,
                      color: AppStyle.dividerColor.withOpacity(0.5),
                      indent: AppStyle.paddingLarge,
                      endIndent: AppStyle.paddingLarge,
                    ),
                  );
                }
              },
            ),
          ),

          // Single Bottom Control Panel
          const _BottomControlPanel(),
        ],
      ),
    );
  }
}

/// Empty state widget (no changes needed from previous version)
class _EmptyTransactionsList extends StatelessWidget {
  const _EmptyTransactionsList();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppStyle.paddingLarge),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long_outlined, // Use outlined icon
              size: 64,
              color: AppStyle.textColorSecondary
                  .withOpacity(0.4), // More subtle color
            ),
            const SizedBox(height: AppStyle.paddingMedium),
            Text(
              'No items found', // Simpler text
              style: AppStyle.titleStyle.copyWith(
                // Slightly larger text
                color: AppStyle.textColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppStyle.paddingSmall),
            Text(
              'Items parsed from the receipt will appear here for review.',
              style: AppStyle.bodyText.copyWith(
                color: AppStyle.textColorSecondary,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

/// Individual transaction list item (no changes needed from previous version)
class _TransactionListItem extends StatelessWidget {
  final Transaction transaction;
  final int index;

  const _TransactionListItem({
    required this.transaction,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final category = transaction.category.target;
    final categoryColor =
        Color(category?.colorValue ?? AppStyle.textColorSecondary.value);
    final categoryIcon = category?.icon ?? Icons.category_outlined;

    return Card(
      margin: const EdgeInsets.symmetric(vertical: AppStyle.paddingXSmall),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
      ),
      elevation: AppStyle.elevationSmall / 2,
      color: AppStyle.cardColor,
      child: Dismissible(
        key: ValueKey(transaction.id ?? transaction.hashCode),
        background: Container(
          decoration: BoxDecoration(
            color: AppStyle.expenseColor,
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: AppStyle.paddingLarge),
          child: const Icon(Icons.delete_outline, color: Colors.white),
        ),
        direction: DismissDirection.endToStart,
        confirmDismiss: (_) => _confirmDeleteItemDialog(context),
        onDismissed: (_) =>
            context.read<BulkTransactionsCubit>().removeTransaction(index),
        child: ListTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: categoryColor.withOpacity(0.15),
            child: Icon(
              categoryIcon,
              color: categoryColor,
              size: 20,
            ),
          ),
          title: Text(
            transaction.title.isEmpty
                ? (category?.title ?? 'Item')
                : transaction.title,
            style: AppStyle.bodyText.copyWith(fontWeight: FontWeight.w500),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          subtitle: Text(
            category?.title ?? 'Uncategorized',
            style: AppStyle.captionStyle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                transaction.amount.toStringAsFixed(2),
                style: AppStyle.bodyText.copyWith(
                  fontWeight: FontWeight.w500,
                  color: transaction.isIncome
                      ? AppStyle.incomeColor
                      : AppStyle.expenseColor,
                ),
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              const Icon(Icons.edit_outlined,
                  size: 18, color: AppStyle.textColorSecondary),
            ],
          ),
          onTap: () => _editTransaction(context, transaction, index),
          contentPadding: const EdgeInsets.symmetric(
              horizontal: AppStyle.paddingMedium,
              vertical: AppStyle.paddingSmall),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
        ),
      ),
    );
  }

  Future<bool> _confirmDeleteItemDialog(BuildContext context) async {
    return await showDialog<bool>(
          context: context,
          builder: (dialogContext) => AlertDialog(
            backgroundColor: AppStyle.cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
            ),
            title: const Text('Delete Item?', style: AppStyle.titleStyle),
            content: const Text(
              'Remove this item from the list?',
              style: AppStyle.bodyText,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogContext).pop(false),
                style: AppStyle.textButtonStyle,
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: () => Navigator.of(dialogContext).pop(true),
                style: AppStyle.dangerButtonStyle,
                child: const Text('Delete'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _editTransaction(
      BuildContext context, Transaction txToEdit, int idx) async {
    final result = await Navigator.push<TransactionResult>(
      context,
      MaterialPageRoute(
        builder: (_) => TransactionFormScreen(transaction: txToEdit),
      ),
    );

    if (result != null && context.mounted) {
      if (result.actionType == ActionType.edit) {
        context
            .read<BulkTransactionsCubit>()
            .updateTransaction(idx, result.transaction);
      }
    }
  }
}

/// Consolidated bottom panel for controls, info, and actions.
class _BottomControlPanel extends StatelessWidget {
  const _BottomControlPanel();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
      // Rebuild frequently as many states affect this panel
      builder: (context, state) {
        final bool totalsMatch =
            (state.totalExpenses - state.receiptTotalAmount).abs() < 0.01;
        final bool listIsEmpty = state.transactions.isEmpty;
        final bool canMerge =
            state.transactions.length > 1; // Condition for enabling merge

        return SafeArea(
          // Keep controls above system intrusions
          child: Container(
            padding: const EdgeInsets.all(AppStyle.paddingMedium),
            decoration: BoxDecoration(
              color: AppStyle.cardColor, // Use card color
              boxShadow: [
                // Consistent shadow
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 15, // Slightly softer shadow
                  offset: const Offset(0, -8),
                ),
              ],
              // Add a top border for clear separation from list
              border: Border(
                  top: BorderSide(color: AppStyle.dividerColor, width: 1)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min, // Take minimum space
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Row 1: Store, Date, Items Total ---
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Store Name (Concise)
                    Flexible(
                      // Allow shrinking/ellipsis
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.store_mall_directory_outlined,
                              size: 16, color: AppStyle.textColorSecondary),
                          const SizedBox(width: AppStyle.paddingXSmall),
                          Flexible(
                            child: Text(
                              state.storeName,
                              style: AppStyle.captionStyle,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppStyle.paddingSmall),
                    // Date (Concise)
                    InkWell(
                      onTap: () => _selectDate(context, state.selectedDate),
                      borderRadius:
                          BorderRadius.circular(AppStyle.borderRadiusSmall),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.calendar_today,
                              size: 16, color: AppStyle.textColorSecondary),
                          const SizedBox(width: AppStyle.paddingXSmall),
                          Text(
                            DateFormat.yMMMd().format(state.selectedDate),
                            style: AppStyle.captionStyle,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: AppStyle.paddingSmall),
                    // Items Total (with visual match/mismatch indicator)
                    if (!listIsEmpty)
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text('Total:', style: AppStyle.captionStyle),
                          const SizedBox(width: AppStyle.paddingXSmall),
                          Text(
                            state.totalExpenses.toStringAsFixed(2),
                            style: AppStyle.bodyText.copyWith(
                              // Use body text for amount
                              fontWeight: FontWeight.w600,
                              color: totalsMatch
                                  ? AppStyle.incomeColor
                                  : (state.warningMessage != null
                                      ? AppStyle.warningColor
                                      : AppStyle
                                          .expenseColor), // Use warning color if warning exists
                            ),
                          ),
                        ],
                      ),
                  ],
                ),
                const SizedBox(height: AppStyle.paddingMedium),

                // --- Row 2: Account Dropdown ---
                AccountDropdown(
                  selectedAccount: state.selectedAccount,
                  onAccountChanged: (account) {
                    if (account != null) {
                      context
                          .read<BulkTransactionsCubit>()
                          .setSelectedAccount(account);
                    }
                  },
                ),
                const SizedBox(height: AppStyle.paddingMedium),

                // --- Row 3: Action Buttons (Merge, Discount) ---
                Row(
                  mainAxisAlignment:
                      MainAxisAlignment.spaceBetween, // Space out buttons
                  children: [
                    // Merge Button (Text Button)
                    TextButton.icon(
                      onPressed: canMerge
                          ? () => context
                              .read<BulkTransactionsCubit>()
                              .mergeTransactionsByCategory()
                          : null, // Disable if cannot merge
                      icon: const Icon(Icons.merge_type, size: 18),
                      label: const Text('Merge Similar'),
                      style: AppStyle.textButtonStyle.copyWith(
                        padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(
                                horizontal: AppStyle.paddingSmall)),
                        // Grey out if disabled
                        foregroundColor:
                            MaterialStateProperty.resolveWith((states) {
                          if (states.contains(MaterialState.disabled))
                            return AppStyle.textColorSecondary.withOpacity(0.5);
                          return AppStyle.primaryColor;
                        }),
                      ),
                    ),

                    // Apply/Remove Discounts Button (Text Button)
                    TextButton.icon(
                      icon: Icon(
                        state.discountsApplied
                            ? Icons.refresh
                            : Icons.local_offer_outlined,
                        size: 18,
                      ),
                      label: Text(state.discountsApplied
                          ? 'Remove Discounts'
                          : 'Apply Discounts'),
                      onPressed: () {
                        if (state.discountsApplied) {
                          context
                              .read<BulkTransactionsCubit>()
                              .restoreOriginalTransactions();
                        } else {
                          context
                              .read<BulkTransactionsCubit>()
                              .processDiscounts();
                        }
                      },
                      style: AppStyle.textButtonStyle.copyWith(
                        padding: MaterialStateProperty.all(
                            const EdgeInsets.symmetric(
                                horizontal: AppStyle.paddingSmall)),
                      ),
                    ),
                  ],
                ),
                const SizedBox(
                    height:
                        AppStyle.paddingMedium), // Space before final buttons

                // --- Warning Message ---
                // Display warning more prominently just above save/cancel if it exists
                if (state.warningMessage != null)
                  Padding(
                    padding:
                        const EdgeInsets.only(bottom: AppStyle.paddingSmall),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: AppStyle.paddingSmall,
                          vertical: AppStyle.paddingXSmall),
                      decoration: BoxDecoration(
                        color: AppStyle.warningColor.withOpacity(0.15),
                        borderRadius:
                            BorderRadius.circular(AppStyle.borderRadiusSmall),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.warning_amber_rounded,
                              color: AppStyle.warningColor, size: 18),
                          const SizedBox(width: AppStyle.paddingSmall),
                          Expanded(
                            child: Text(
                              state.warningMessage!,
                              style: AppStyle.captionStyle
                                  .copyWith(color: AppStyle.warningColor),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                // --- Row 4: Final Save/Cancel Buttons ---
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(context),
                        style: AppStyle.secondaryButtonStyle,
                        child: const Text('Cancel'),
                      ),
                    ),
                    const SizedBox(width: AppStyle.paddingMedium),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton(
                        onPressed: listIsEmpty
                            ? null
                            : () {
                                final processedTransactions =
                                    state.transactions;
                                Navigator.pop(context, processedTransactions);
                              },
                        style: AppStyle.primaryButtonStyle,
                        child: const Text('Save Items'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // Helper method to show date picker - Moved from _GlobalInfoAndActionsSection
  Future<void> _selectDate(BuildContext context, DateTime initialDate) async {
    final DateTime? pickedDate = await showDatePicker(
        context: context,
        initialDate: initialDate,
        firstDate: DateTime(2000),
        lastDate: DateTime(2100),
        builder: (context, child) {
          // Ensure consistent dialog theme
          return Theme(
            data: Theme.of(context).copyWith(
              colorScheme: Theme.of(context).colorScheme.copyWith(
                    primary: AppStyle.primaryColor,
                    onPrimary: ColorPalette.onPrimary,
                    surface: AppStyle.cardColor,
                    onSurface: AppStyle.textColorPrimary,
                  ),
              textButtonTheme: TextButtonThemeData(
                style: TextButton.styleFrom(
                  foregroundColor: AppStyle.primaryColor,
                ),
              ),
              dialogBackgroundColor: AppStyle.cardColor,
            ),
            child: child!,
          );
        });

    if (pickedDate != null && context.mounted) {
      // Access cubit via context.read ONLY if _BottomControlPanel's context has it.
      // If the Builder wasn't used above, this context might not have it.
      // Ensure the context used here can access the BulkTransactionsCubit.
      context.read<BulkTransactionsCubit>().setSelectedDate(pickedDate);
    }
  }
}
