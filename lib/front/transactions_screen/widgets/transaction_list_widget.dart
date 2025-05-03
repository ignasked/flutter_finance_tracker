import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart'; // Import Bloc for context.read
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:sticky_headers/sticky_headers.dart'; // Import sticky_headers
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart'; // Import Cubit
import 'package:money_owl/front/transactions_screen/viewmodel/transaction_viewmodel.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart'; // Add import
import 'package:money_owl/backend/models/transaction_result.dart'; // Add import
import 'package:money_owl/front/transaction_form_screen/cubit/transaction_form_cubit.dart'; // Add import for ActionType
import 'package:money_owl/front/receipt_scan/bulk_add/cubit/bulk_transactions_cubit.dart'; // Import BulkTransactionsCubit
// Unused imports removed
import 'package:money_owl/backend/utils/defaults.dart'; // For default category/account

class TransactionListWidget extends StatelessWidget {
  final List<TransactionViewModel> transactions;
  final bool groupByMonth;
  final bool isBulkAddContext;

  const TransactionListWidget({
    Key? key,
    required this.transactions,
    this.groupByMonth = false,
    this.isBulkAddContext = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          // Use padding from previous style
          padding: EdgeInsets.all(AppStyle.paddingLarge),
          child: Text(
            'No transactions found for the selected period. Try adjusting the filters!',
            style: AppStyle.bodyText,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    // Choose build method based on groupByMonth
    if (groupByMonth) {
      return _buildGroupedList(context);
    } else {
      return _buildFlatList(context);
    }
  }

  // --- Build Methods (Adapted for ViewModel) ---

  Widget _buildFlatList(BuildContext context) {
    return ListView.separated(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final item = transactions[index];
        // Use ViewModel's id for the key
        return _buildDismissibleItem(context, item, ValueKey(item.id));
      },
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: AppStyle.dividerColor.withOpacity(0.5), // Softer divider
        indent: AppStyle.paddingMedium +
            40 + // Avatar radius (20*2)
            AppStyle.paddingMedium, // Indent past avatar
        endIndent: AppStyle.paddingMedium,
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    // Use adapted grouping method
    Map<String, List<TransactionViewModel>> groupedTransactions =
        _groupTransactionsByMonth(transactions);
    var sortedMonthKeys = groupedTransactions.keys.toList();

    return ListView.builder(
      itemCount: sortedMonthKeys.length, // Number of months
      itemBuilder: (context, monthIndex) {
        final monthKey = sortedMonthKeys[monthIndex]; // Format: YYYY-MM
        final monthTransactions = groupedTransactions[monthKey]!;
        final displayMonth = _formatDisplayMonth(monthKey); // Use helper

        return StickyHeader(
          header:
              _buildMonthHeader(context, displayMonth), // Use header builder
          content: Column(
            children: List.generate(monthTransactions.length, (itemIndex) {
              final item = monthTransactions[itemIndex];
              final isLastItemOfMonth =
                  itemIndex == monthTransactions.length - 1;
              // Use ViewModel's id for the key
              final itemWidget =
                  _buildDismissibleItem(context, item, ValueKey(item.id));

              // Add divider unless it's the last item in the month group
              if (!isLastItemOfMonth) {
                return Column(
                  children: [
                    itemWidget,
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppStyle.dividerColor.withOpacity(0.5),
                      indent: AppStyle.paddingMedium +
                          40 + // Avatar radius (20*2)
                          AppStyle.paddingMedium, // Indent past avatar
                      endIndent: AppStyle.paddingMedium,
                    )
                  ],
                );
              } else {
                return itemWidget; // No divider after the last item
              }
            }),
          ),
        );
      },
    );
  }

  Widget _buildMonthHeader(BuildContext context, String displayMonth) {
    return Container(
      height: 45.0, // Consistent header height
      color:
          AppStyle.backgroundColor, // Use background color to overlay content
      padding: const EdgeInsets.symmetric(horizontal: AppStyle.paddingMedium),
      alignment: Alignment.centerLeft,
      child: Text(
        displayMonth,
        // Use styles from previous version
        style: AppStyle.subtitleStyle.copyWith(
          fontWeight: FontWeight.w600,
          color: AppStyle.textColorSecondary,
        ),
      ),
    );
  }

  // --- Build Dismissible Item (Corrected Logic) ---
  Widget _buildDismissibleItem(
      BuildContext context, TransactionViewModel item, Key key) {
    // --- FIX: Use ObjectKey in bulk add context for potentially non-unique IDs ---
    final dismissibleKey = isBulkAddContext ? ObjectKey(item) : key;

    return Dismissible(
      key: dismissibleKey, // Use the determined key
      direction: DismissDirection.endToStart,
      // --- confirmDismiss: ONLY shows dialog and returns boolean ---
      confirmDismiss: (direction) async {
        return await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirm Deletion'),
              content: const Text(
                  'Are you sure you want to delete this transaction?'),
              actions: <Widget>[
                TextButton(
                  child: const Text('Cancel'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(false); // Return false
                  },
                ),
                TextButton(
                  style: TextButton.styleFrom(
                      foregroundColor: AppStyle.expenseColor),
                  child: const Text('Delete'),
                  onPressed: () {
                    Navigator.of(dialogContext).pop(true); // Return true
                  },
                ),
              ],
            );
          },
        );
        // --- NO cubit calls here ---
      },
      background: Container(
        color: AppStyle.expenseColor,
        alignment: Alignment.centerRight,
        padding: const EdgeInsets.symmetric(horizontal: 20.0),
        child: const Icon(Icons.delete_outline, color: Colors.white),
      ),
      // --- onDismissed: Contains the actual deletion logic ---
      onDismissed: (direction) {
        // This code runs *only if* confirmDismiss returned true
        if (isBulkAddContext) {
          // Bulk Add Context: Remove from BulkTransactionsCubit
          final index = transactions.indexWhere((vm) => vm == item);
          if (index != -1) {
            context.read<BulkTransactionsCubit>().removeTransaction(index);
          } else {
            print("Error: Dismissed item not found in Bulk Add list.");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error removing item.',
                      style: AppStyle.bodyText.copyWith(color: Colors.white)),
                  backgroundColor: AppStyle.expenseColor),
            );
          }
        } else {
          // Normal Context: Remove from DataManagementCubit
          if (item.id > 0) {
            context.read<DataManagementCubit>().deleteTransaction(item.id);
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Transaction deleted.',
                      style: AppStyle.bodyText.copyWith(color: Colors.white)),
                  backgroundColor: Colors.grey[700]),
            );
          } else {
            print("Error: Cannot delete transaction with ID 0 via dismiss.");
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content: Text('Error deleting transaction.',
                      style: AppStyle.bodyText.copyWith(color: Colors.white)),
                  backgroundColor: AppStyle.expenseColor),
            );
          }
        }
      },
      child: _buildTransactionTile(context, item),
    );
  }
  // --- End Corrected Logic ---

  // --- Build Transaction Tile (Adapted for ViewModel and Edit Navigation) ---
  Widget _buildTransactionTile(
      BuildContext context, TransactionViewModel item) {
    return ListTile(
      leading: CircleAvatar(
        radius: 20, // Standard avatar size
        backgroundColor: item.categoryColor
            .withOpacity(0.1), // Use ViewModel's category color
        child: Icon(
          item.categoryIcon, // Use ViewModel's category icon
          size: 20,
          // Use category color directly if needed, or keep default
          color: item.categoryColor,
        ),
      ),
      title: Text(item.title, // Use ViewModel's title
          style: AppStyle.titleStyle, // Use previous style
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        // Combine category name and display date from ViewModel
        '${item.categoryName} • ${item.displayDate}',
        style: AppStyle.captionStyle, // Use previous style
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        // Use displayAmount directly from ViewModel
        item.displayAmount,
        // Use previous styles based on isIncome from ViewModel
        style: item.isIncome
            ? AppStyle.amountIncomeStyle
            : AppStyle.amountExpenseStyle,
      ),
      // --- UPDATED: onTap logic with context check ---
      onTap: () async {
        if (isBulkAddContext) {
          // --- Bulk Add Context ---
          final index = transactions.indexWhere((vm) => vm == item);

          if (index != -1) {
            final bulkCubit = context.read<BulkTransactionsCubit>();
            if (index < bulkCubit.state.transactions.length) {
              final rawTransaction = bulkCubit.state.transactions[index];

              // --- FIX: Prepare Transaction with populated relations ---
              // Fetch Category and Account from BulkCubit's cache
              final category = bulkCubit.allCategories.firstWhere(
                  (c) => c.id == rawTransaction.category.targetId,
                  orElse: () =>
                      Defaults().defaultCategory); // Use default as fallback
              final account = bulkCubit.allAccounts.firstWhere(
                  (a) => a.id == rawTransaction.fromAccount.targetId,
                  orElse: () =>
                      Defaults().defaultAccount); // Use default as fallback

              // Create a temporary Transaction instance with relations set
              final transactionForForm = Transaction(
                id: rawTransaction.id, // Keep original ID (likely 0)
                uuid: rawTransaction.uuid,
                title: rawTransaction.title,
                amount: rawTransaction.amount,
                date: rawTransaction.date,
                description: rawTransaction.description,
                createdAt: rawTransaction.createdAt,
                updatedAt: rawTransaction.updatedAt,
                deletedAt: rawTransaction.deletedAt,
                userId: rawTransaction.userId,
                metadata: rawTransaction.metadata,
              )
                ..category.target = category
                ..fromAccount.target = account;

              final TransactionResult? result =
                  await Navigator.push<TransactionResult>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TransactionFormScreen(transaction: transactionForForm),
                ),
              );

              if (result != null &&
                  result.actionType == ActionType.edit &&
                  context.mounted) {
                bulkCubit.updateTransaction(index, result.transaction);
              }
            } else {
              print(
                  "Error: Index mismatch between displayed and raw lists in Bulk Add.");
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                      content: Text('Error editing item.',
                          style:
                              AppStyle.bodyText.copyWith(color: Colors.white)),
                      backgroundColor: AppStyle.expenseColor),
                );
              }
            }
          } else {
            print("Error: Tapped item not found in Bulk Add list.");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                    content: Text('Error finding item to edit.',
                        style: AppStyle.bodyText.copyWith(color: Colors.white)),
                    backgroundColor: AppStyle.expenseColor),
              );
            }
          }
        } else {
          // --- Normal Context (e.g., TransactionsScreen) ---
          if (item.id > 0) {
            final dataCubit = context.read<DataManagementCubit>();
            final Transaction? transactionToEdit =
                await dataCubit.getTransactionForEditing(item.id);

            if (transactionToEdit != null && context.mounted) {
              final TransactionResult? result =
                  await Navigator.push<TransactionResult>(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      TransactionFormScreen(transaction: transactionToEdit),
                ),
              );

              if (result != null && context.mounted) {
                dataCubit.handleTransactionFormResult(result);
              }
            } else if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: Could not load transaction details.',
                      style: AppStyle.bodyText.copyWith(color: Colors.white)),
                  backgroundColor: AppStyle.expenseColor,
                ),
              );
            }
          } else {
            print("Error: Cannot edit transaction with ID 0 in this context.");
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: Cannot edit this transaction.',
                      style: AppStyle.bodyText.copyWith(color: Colors.white)),
                  backgroundColor: AppStyle.expenseColor,
                ),
              );
            }
          }
        }
      },
      // --- END UPDATED: onTap logic ---
    );
  }

  // --- Helper Methods (Adapted for ViewModel) ---

  // Group transactions by month (YYYY-MM format) - Adapted for ViewModel
  Map<String, List<TransactionViewModel>> _groupTransactionsByMonth(
      List<TransactionViewModel> transactions) {
    Map<String, List<TransactionViewModel>> grouped = {};
    // Ensure transactions are sorted descending first
    // Use the 'date' field from ViewModel
    transactions.sort((a, b) => b.date.compareTo(a.date));

    for (var transaction in transactions) {
      // Use the 'date' field from ViewModel
      final monthYear = DateFormat('yyyy-MM').format(transaction.date);
      grouped.putIfAbsent(monthYear, () => []).add(transaction);
    }
    // Sort keys to ensure months are in descending order (most recent first)
    var sortedKeys = grouped.keys.toList();
    sortedKeys
        .sort((a, b) => b.compareTo(a)); // Simple string sort works for YYYY-MM

    // Create a new map with sorted keys
    Map<String, List<TransactionViewModel>> sortedGrouped = {};
    for (var key in sortedKeys) {
      sortedGrouped[key] = grouped[key]!;
    }
    return sortedGrouped;
  }

  // Format month key (YYYY-MM) to display format (e.g., October 2023) - No changes needed
  String _formatDisplayMonth(String monthKey) {
    final year = int.parse(monthKey.split('-')[0]);
    final month = int.parse(monthKey.split('-')[1]);
    return DateFormat('MMMM yyyy').format(DateTime(year, month));
  }
}
