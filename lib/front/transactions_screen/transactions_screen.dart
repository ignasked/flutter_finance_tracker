import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
import 'package:money_owl/backend/utils/enums.dart'; // Import enums
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart'; // Updated import
import 'package:money_owl/front/transactions_screen/widgets/date_bar_widget.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/front/transactions_screen/widgets/transaction_list_widget.dart';
import 'package:money_owl/front/transactions_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/receipt_scan_screen/receipt_analyzer_widget.dart';

class TransactionsScreen extends StatelessWidget {
  const TransactionsScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppStyle.backgroundColor, // Use AppStyle background
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(
              AppStyle.paddingMedium), // Use AppStyle padding
          child: BlocBuilder<TransactionsCubit, TransactionsState>(
            // Updated BlocBuilder
            builder: (context, state) {
              // Use a common structure and conditionally show the list or empty message
              return Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch, // Stretch children horizontally
                children: [
                  // Transaction Summary
                  const SummaryBarWidget(),
                  const SizedBox(
                      height: AppStyle.paddingMedium), // Use AppStyle padding

                  // Date Selector
                  const DateBarWidget(),
                  const SizedBox(
                      height: AppStyle.paddingMedium), // Use AppStyle padding

                  // Transaction List or Empty Message
                  Expanded(
                    child: state.status ==
                            LoadingStatus.loading // Use LoadingStatus
                        ? const Center(child: CircularProgressIndicator())
                        : state.displayedTransactions.isEmpty
                            ? const Center(
                                child: Text(
                                  'No transactions for this period.',
                                  style: AppStyle.bodyText, // Use AppStyle
                                ),
                              )
                            : TransactionListWidget(
                                transactions: state.displayedTransactions,
                                groupByMonth: true, // Group by month by default
                              ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          _showBottomSheet(context);
        },
        backgroundColor: AppStyle.primaryColor, // Use AppStyle primary color
        child: const Icon(Icons.add,
            color: Colors.white), // Ensure icon is visible
      ),
    );
  }

  /// Show the bottom sheet for adding transactions or scanning receipts
  void _showBottomSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.backgroundColor, // Use AppStyle background
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
            top: Radius.circular(
                AppStyle.paddingMedium)), // Use AppStyle padding
      ),
      builder: (sheetContext) {
        // Use sheetContext
        return Padding(
          padding: const EdgeInsets.all(
              AppStyle.paddingLarge), // Use AppStyle padding
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: AppStyle.primaryColor), // Use AppStyle color
                title: const Text('Add Transaction',
                    style: AppStyle.titleStyle), // Use AppStyle
                onTap: () async {
                  Navigator.pop(sheetContext); // Close the bottom sheet first
                  final TransactionResult? transactionFormResult =
                      await Navigator.push<TransactionResult>(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TransactionFormScreen(),
                    ),
                  );

                  if (!context.mounted) return;

                  if (transactionFormResult != null) {
                    // Always handle the result through the cubit
                    context
                        .read<TransactionsCubit>()
                        .handleTransactionFormResult(transactionFormResult);
                  }
                },
              ),
              const Divider(
                  color: AppStyle.dividerColor), // Use AppStyle divider
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined,
                    color: AppStyle.primaryColor), // Use AppStyle color
                title: const Text('Scan Receipt',
                    style: AppStyle.titleStyle), // Use AppStyle
                onTap: () {
                  Navigator.pop(sheetContext); // Close the first bottom sheet
                  showModalBottomSheet(
                    context: context,
                    isScrollControlled: true,
                    backgroundColor:
                        AppStyle.backgroundColor, // Use AppStyle background
                    shape: const RoundedRectangleBorder(
                      borderRadius: BorderRadius.vertical(
                          top: Radius.circular(
                              AppStyle.paddingMedium)), // Use AppStyle padding
                    ),
                    builder: (context) {
                      // Wrap ReceiptAnalyzerWidget for better layout control if needed
                      return const Padding(
                        padding: EdgeInsets.all(AppStyle.paddingMedium),
                        child: ReceiptAnalyzerWidget(),
                      );
                    },
                  );
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
