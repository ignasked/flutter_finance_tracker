import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:sticky_headers/sticky_headers.dart'; // Import sticky_headers
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
// Assuming TransactionRepository is primarily used within the Cubit now
// import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/backend/utils/app_style.dart';

class TransactionListWidget extends StatelessWidget {
  final List<Transaction> transactions;
  final bool groupByMonth;

  const TransactionListWidget({
    Key? key,
    required this.transactions,
    this.groupByMonth = false,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    if (transactions.isEmpty) {
      return const Center(
        child: Padding(
          // Add some padding to the empty message
          padding: EdgeInsets.all(AppStyle.paddingLarge),
          child: Text(
            'No transactions found for the selected period. Try adjusting the filters!',
            style: AppStyle.bodyText,
            textAlign: TextAlign.center,
          ),
        ),
      );
    }

    if (groupByMonth) {
      return _buildGroupedList(context);
    } else {
      return _buildFlatList(context);
    }
  }

  // --- Build Methods ---

  Widget _buildFlatList(BuildContext context) {
    return ListView.separated(
      itemCount: transactions.length,
      itemBuilder: (context, index) {
        final item = transactions[index];
        // Use a unique key based on the transaction ID for Dismissible
        return _buildDismissibleItem(context, item, ValueKey(item.id));
      },
      separatorBuilder: (context, index) => Divider(
        height: 1,
        thickness: 1,
        color: AppStyle.dividerColor.withOpacity(0.5), // Softer divider
        indent: AppStyle.paddingMedium +
            40 +
            AppStyle.paddingMedium, // Indent past avatar
        endIndent: AppStyle.paddingMedium,
      ),
    );
  }

  Widget _buildGroupedList(BuildContext context) {
    Map<String, List<Transaction>> groupedTransactions =
        _groupTransactionsByMonth(transactions);
    var sortedMonthKeys = groupedTransactions.keys
        .toList(); // Already sorted by _groupTransactionsByMonth

    return ListView.builder(
      itemCount: sortedMonthKeys.length, // Number of months
      itemBuilder: (context, monthIndex) {
        final monthKey = sortedMonthKeys[monthIndex]; // Format: YYYY-MM
        final monthTransactions = groupedTransactions[monthKey]!;
        final displayMonth = _formatDisplayMonth(monthKey);

        return StickyHeader(
          header: _buildMonthHeader(context, displayMonth),
          content: Column(
            // Use Column to list items for this month
            children: List.generate(monthTransactions.length, (itemIndex) {
              final item = monthTransactions[itemIndex];
              final isLastItemOfMonth =
                  itemIndex == monthTransactions.length - 1;
              // Use a unique key based on the transaction ID for Dismissible
              final itemWidget =
                  _buildDismissibleItem(context, item, ValueKey(item.id));

              // Add divider *unless* it's the last item in the month group
              if (!isLastItemOfMonth) {
                return Column(
                  children: [
                    itemWidget,
                    Divider(
                      height: 1,
                      thickness: 1,
                      color: AppStyle.dividerColor.withOpacity(0.5),
                      indent: AppStyle.paddingMedium +
                          40 +
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
        style: AppStyle.subtitleStyle.copyWith(
          fontWeight: FontWeight.w600, // Make header slightly bolder
          color: AppStyle.textColorSecondary,
        ),
      ),
    );
  }

  // --- Build Dismissible Item ---
  Widget _buildDismissibleItem(
      BuildContext context, Transaction item, Key key) {
    // Get cubit instance once
    final txCubit = context.read<DataManagementCubit>();

    return Dismissible(
      key: key, // Use the provided unique key
      direction: DismissDirection.endToStart, // Only allow swipe left to delete
      confirmDismiss: (direction) async {
        // Show confirmation dialog
        final bool? confirm = await showDialog<bool>(
          context: context,
          builder: (BuildContext dialogContext) {
            return AlertDialog(
              title: const Text('Confirm Delete', style: AppStyle.heading2),
              content: const Text(
                  'Are you sure you want to delete this transaction?',
                  style: AppStyle.bodyText),
              backgroundColor:
                  AppStyle.cardColor, // Use cardColor for dialog background
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(
                    AppStyle.borderRadiusMedium), // Consistent radius
              ),
              actions: <Widget>[
                TextButton(
                  style: AppStyle.textButtonStyle.copyWith(
                    foregroundColor:
                        WidgetStateProperty.all(AppStyle.textColorSecondary),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  style: AppStyle.textButtonStyle.copyWith(
                    foregroundColor:
                        WidgetStateProperty.all(AppStyle.expenseColor),
                  ),
                  onPressed: () => Navigator.of(dialogContext).pop(true),
                  child: const Text('Delete'),
                ),
              ],
            );
          },
        );

        // If confirmed, trigger deletion via Cubit
        if (confirm == true) {
          // IMPORTANT: Let the Cubit handle repository interaction and state update
          txCubit.deleteTransaction(item.id);

          // Optional: Show snackbar immediately, or wait for state change confirmation
          if (context.mounted) {
            // Check context validity after async gap
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('${item.title} deleted.',
                    style: AppStyle.bodyText.copyWith(color: Colors.white)),
                backgroundColor:
                    AppStyle.textColorPrimary, // Or a success/info color
                behavior: SnackBarBehavior.floating, // Looks nicer
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusSmall)),
              ),
            );
          }
          return true; // Allow dismissal animation
        }
        return false; // Prevent dismissal if cancelled
      },
      background: Container(
        color: AppStyle.expenseColor,
        padding: const EdgeInsets.symmetric(horizontal: AppStyle.paddingLarge),
        alignment: Alignment.centerRight,
        child: const Icon(
          Icons.delete_sweep_outlined, // A slightly different delete icon
          color: Colors.white,
        ),
      ),
      child:
          _buildTransactionTile(context, item, txCubit), // Pass cubit for onTap
    );
  }

  // --- Build Transaction Tile (Content of Dismissible) ---
  Widget _buildTransactionTile(
      BuildContext context, Transaction item, DataManagementCubit txCubit) {
    final category = item.category.target;
    // More user-friendly date format for the tile itself
    final dateFormat = DateFormat.Md(Localizations.localeOf(context)
        .languageCode); // e.g., 10/26 or Oct 26 based on locale

    return ListTile(
      // Use ListTileTheme defined in AppStyle for consistent padding/shape if available
      // contentPadding: EdgeInsets.symmetric(horizontal: AppStyle.paddingMedium, vertical: AppStyle.paddingSmall), // Manual padding if no theme
      leading: CircleAvatar(
        radius: 20, // Standard avatar size
        backgroundColor: category?.color ??
            AppStyle.textColorSecondary
                .withOpacity(0.1), // Use category color or a default
        child: Icon(
            category?.icon ?? Icons.question_mark, // Use a placeholder icon
            size: 20,
            color: Colors.black),
      ),
      title: Text(item.title,
          style: AppStyle.titleStyle,
          maxLines: 1,
          overflow: TextOverflow.ellipsis),
      subtitle: Text(
        '${category?.title ?? 'Uncategorized'} • ${dateFormat.format(item.date)}',
        style: AppStyle.captionStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        '${item.isIncome ? '+' : '-'}${item.amountAndCurrencyString}',
        style: item.isIncome
            ? AppStyle.amountIncomeStyle
            : AppStyle.amountExpenseStyle,
      ),
      onTap: () async {
        // Navigate to edit screen, passing the transaction object directly
        final TransactionResult? transactionFormResult =
            await Navigator.push<TransactionResult>(
          context,
          MaterialPageRoute(
            // Pass the actual transaction, not index
            builder: (context) => TransactionFormScreen(transaction: item),
          ),
        );

        // Let the Cubit handle the result (which should contain the transaction ID)
        if (transactionFormResult != null && context.mounted) {
          context
              .read<DataManagementCubit>()
              .handleTransactionFormResult(transactionFormResult);
        }
      },
      // Add visual density for tighter packing if desired
      // visualDensity: VisualDensity.compact,
    );
  }

  // --- Helper Methods ---

  // Group transactions by month (YYYY-MM format)
  Map<String, List<Transaction>> _groupTransactionsByMonth(
      List<Transaction> transactions) {
    Map<String, List<Transaction>> grouped = {};
    // Ensure transactions are sorted descending first (most recent month/day first)
    transactions.sort((a, b) => b.date.compareTo(a.date));

    for (var transaction in transactions) {
      final monthYear = DateFormat('yyyy-MM').format(transaction.date);
      grouped.putIfAbsent(monthYear, () => []).add(transaction);
    }
    return grouped; // Keys will be naturally sorted if needed, but sorting done above ensures order within months
  }

  // Format month key (YYYY-MM) to display format (e.g., October 2023)
  String _formatDisplayMonth(String monthKey) {
    final year = int.parse(monthKey.split('-')[0]);
    final month = int.parse(monthKey.split('-')[1]);
    // Use DateFormat for locale-aware month name
    return DateFormat('MMMM yyyy').format(DateTime(year, month));
  }
}
