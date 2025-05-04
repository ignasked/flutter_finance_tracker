import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/utils/app_style.dart'; // Import AppStyle
import 'package:money_owl/backend/utils/enums.dart'; // Import enums
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart'; // Updated import
import 'package:money_owl/front/transactions_screen/widgets/date_bar_widget.dart';
import 'package:money_owl/front/transaction_form_screen/transaction_form_screen.dart';
import 'package:money_owl/front/transactions_screen/widgets/transaction_list_widget.dart';
import 'package:money_owl/front/transactions_screen/widgets/summary_bar_widget.dart';
import 'package:money_owl/front/receipt_scan/receipt_analyzer/receipt_analyzer_widget.dart';

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
          child: BlocBuilder<DataManagementCubit, DataManagementState>(
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
                      height: AppStyle.paddingSmall), // Use AppStyle padding

                  // Date Selector
                  const DateBarWidget(),
                  const SizedBox(
                      height: AppStyle.paddingSmall), // Use AppStyle padding

                  // Transaction List or Empty Message
                  Expanded(
                    child: state.status ==
                            LoadingStatus.loading // Use LoadingStatus
                        ? const Center(child: CircularProgressIndicator())
                        : state.displayedTransactions.isEmpty
                            // --- USE DETAILED EMPTY STATE WIDGET ---
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                    vertical: AppStyle.paddingXLarge *
                                        1.5), // Adjusted padding slightly
                                alignment: Alignment.center,
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                        Icons
                                            .receipt_long_outlined, // Changed Icon
                                        size: 60,
                                        color: AppStyle.textColorSecondary
                                            .withOpacity(0.5)),
                                    const SizedBox(
                                        height: AppStyle.paddingMedium),
                                    const Text(
                                      'No Transactions Found', // Updated Text
                                      style: AppStyle.titleStyle,
                                      textAlign: TextAlign.center,
                                    ),
                                    const SizedBox(
                                        height: AppStyle.paddingSmall),
                                    Text(
                                      'Try adjusting the date range or add a new transaction.', // Updated Text
                                      style: AppStyle.bodyText.copyWith(
                                          color: AppStyle.textColorSecondary),
                                      textAlign: TextAlign.center,
                                    ),
                                  ],
                                ),
                              )
                            // --- END EMPTY STATE WIDGET ---
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
      isScrollControlled: true, // Allows sheet to take more height if needed
      backgroundColor: AppStyle.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(
              AppStyle.borderRadiusLarge), // Slightly larger radius for sheet
        ),
      ),
      builder: (sheetContext) {
        // Use sheetContext
        return Padding(
          // Padding includes space for keyboard if it appears
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(sheetContext).viewInsets.bottom,
            left: AppStyle.paddingMedium,
            right: AppStyle.paddingMedium,
            top: AppStyle
                .paddingSmall, // Less top padding needed due to handle/title
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min, // Take only needed height
            children: [
              // --- Drag Handle ---
              Container(
                width: 40,
                height: 5,
                margin: const EdgeInsets.only(bottom: AppStyle.paddingMedium),
                decoration: BoxDecoration(
                  color: AppStyle.dividerColor.withOpacity(0.5),
                  borderRadius:
                      BorderRadius.circular(AppStyle.borderRadiusSmall),
                ),
              ),

              // --- List Tiles ---
              ListTile(
                leading: const Icon(Icons.add_circle_outline,
                    color: AppStyle.primaryColor),
                title: const Text('Add Transaction',
                    style: AppStyle.titleStyle), // Use bodyText for options
                shape: RoundedRectangleBorder(
                  // Add shape for tap feedback area
                  borderRadius:
                      BorderRadius.circular(AppStyle.borderRadiusMedium),
                ),
                onTap: () async {
                  Navigator.pop(sheetContext); // Close the bottom sheet first
                  final TransactionResult? transactionFormResult =
                      await Navigator.push<TransactionResult>(
                    context,
                    MaterialPageRoute(
                      // Pass the context from the main screen, not sheetContext
                      builder: (context) => const TransactionFormScreen(),
                    ),
                  );

                  // Use the original context here
                  if (!context.mounted) return;

                  if (transactionFormResult != null) {
                    context
                        .read<DataManagementCubit>()
                        .handleTransactionFormResult(transactionFormResult);
                  }
                },
              ),
              const Divider(
                color: AppStyle.dividerColor,
                height: AppStyle.paddingSmall, // Reduce divider height
                indent: AppStyle.paddingMedium, // Indent divider slightly
                endIndent: AppStyle.paddingMedium,
              ),
              ListTile(
                leading: const Icon(Icons.receipt_long_outlined,
                    color: AppStyle.primaryColor),
                title: const Text('Scan Receipt',
                    style: AppStyle.titleStyle), // Use bodyText
                shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppStyle.borderRadiusMedium),
                ),
                onTap: () {
                  Navigator.pop(sheetContext); // Close the first bottom sheet
                  // Show the second sheet for scanning options
                  _showReceiptAnalyzerSheet(context); // Use helper function
                },
              ),
              const SizedBox(height: AppStyle.paddingMedium), // Bottom padding
            ],
          ),
        );
      },
    );
  }

  // Helper function to show the Receipt Analyzer bottom sheet
  void _showReceiptAnalyzerSheet(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppStyle.backgroundColor,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppStyle.borderRadiusLarge),
        ),
      ),
      builder: (analyzerSheetContext) {
        return const ReceiptAnalyzerWidget(); // Directly use the styled widget
      },
    );
  }
}
