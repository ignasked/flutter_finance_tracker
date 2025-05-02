import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/file_picker_service.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/receipt_format.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';
import 'package:money_owl/front/receipt_scan_screen/bulk_add_transactions_screen.dart';
import 'package:money_owl/front/receipt_scan_screen/receipt_analysis_cubit.dart';
import 'package:money_owl/front/common/loading_widget.dart';

class ReceiptAnalyzerButton extends StatelessWidget {
  final VoidCallback onTap;

  const ReceiptAnalyzerButton({Key? key, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading: const Icon(Icons.receipt),
      title: const Text('Read Receipt'),
      onTap: onTap,
    );
  }
}

class ReceiptAnalyzerWidget extends StatelessWidget {
  const ReceiptAnalyzerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    // Use BlocProvider here if ReceiptAnalyzerWidget is always shown within its own sheet
    // If it might be used elsewhere, the provider might be placed higher up.
    return BlocProvider(
      create: (context) => ReceiptAnalysisCubit(
        MistralService.instance,
        context
            .read<CategoryRepository>(), // Reads from context above the sheet
      ),
      child: BlocConsumer<ReceiptAnalysisCubit, ReceiptAnalysisState>(
        listener: (context, state) async {
          // Handle Loading state change
          if (state is ReceiptAnalysisLoading) {
            // Show loading popup for any loading state
            showLoadingPopup(context, message: 'Analyzing receipt...');
          } else {
            // Hide loading if the state is NOT loading
            // hideLoadingPopup is safe to call even if nothing is showing
            hideLoadingPopup(context);
          }

          // Handle Error state
          if (state is ReceiptAnalysisError) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.message,
                      style: AppStyle.bodyText
                          .copyWith(color: ColorPalette.onError)),
                  backgroundColor: ColorPalette.errorContainer,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium),
                  ),
                  margin: const EdgeInsets.all(AppStyle.paddingSmall),
                ),
              );
          }
          // Handle Success state
          else if (state is ReceiptAnalysisSuccess) {
            // Ensure context is still valid before navigating
            if (!context.mounted) return;

            final receiptData = state.receiptData;

            // Add debug logging to track what we're receiving
            print(
                'Receipt data transactions type: ${receiptData['transactions'].runtimeType}');
            print(
                'Receipt data transactions count: ${receiptData['transactions'] is List ? (receiptData['transactions'] as List).length : 'not a list'}');

            // Make sure we have a valid list of Transaction objects
            List<Transaction> transactions = [];
            if (receiptData['transactions'] is List) {
              transactions = (receiptData['transactions'] as List)
                  .whereType<Transaction>()
                  .toList();
              print('Valid Transaction objects found: ${transactions.length}');
            }

            // Navigate to Bulk Add screen
            final addedTransactions = await Navigator.push<List<Transaction>?>(
              context,
              MaterialPageRoute(
                builder: (_) => BulkAddTransactionsScreen(
                  transactionName: receiptData['transactionName'] is String
                      ? receiptData['transactionName'] as String
                      : "Unknown Store",
                  date: receiptData['date'] is DateTime
                      ? receiptData['date'] as DateTime
                      : DateTime.now(),
                  totalExpensesFromReceipt:
                      receiptData['totalAmountPaid'] is num
                          ? (receiptData['totalAmountPaid'] as num).toDouble()
                          : 0.0,
                  transactions: transactions,
                ),
              ),
            );

            // Ensure context is still valid after navigation
            if (!context.mounted) return;

            if (addedTransactions != null && addedTransactions.isNotEmpty) {
              // Add to repository and update the UI through TransactionsCubit
              context
                  .read<TransactionsCubit>()
                  .addTransactions(addedTransactions);

              // Show success message
              ScaffoldMessenger.of(context)
                ..hideCurrentSnackBar()
                ..showSnackBar(
                  SnackBar(
                    content: Text(
                        '${addedTransactions.length} transactions added!',
                        style: AppStyle.bodyText
                            .copyWith(color: ColorPalette.onPrimary)),
                    backgroundColor: AppStyle.incomeColor,
                    behavior: SnackBarBehavior.floating,
                    shape: RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(AppStyle.borderRadiusMedium)),
                    margin: const EdgeInsets.all(AppStyle.paddingSmall),
                  ),
                );

              // Close the bottom sheet after successful addition
              Navigator.pop(context);
            }
          }
        },
        builder: (context, state) {
          final File? imageFile = // Use File? for null safety
              state is ReceiptAnalysisImageSelected ? state.imageFile : null;

          return Padding(
            // Padding includes space for keyboard if it appears (though less likely here)
            padding: EdgeInsets.only(
              bottom: MediaQuery.of(context).viewInsets.bottom,
              left: AppStyle.paddingMedium,
              right: AppStyle.paddingMedium,
              top: AppStyle.paddingSmall,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment
                  .stretch, // Stretch elements like buttons if needed
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
                // --- Title ---
                const Padding(
                  padding: EdgeInsets.only(
                      bottom: AppStyle.paddingMedium), // More space after title
                  child: Text(
                    'Select Receipt Source',
                    style: AppStyle.titleStyle,
                    textAlign: TextAlign.center, // Center the title
                  ),
                ),

                // --- Action List Tiles (Styled) ---
                _buildScanOptionTile(
                  context: context,
                  icon: Icons.picture_as_pdf_outlined,
                  title: 'From PDF (Recommended)',
                  onTap: () async {
                    final pdfFile = await FilePickerService.instance.pickPDF();
                    if (pdfFile != null && context.mounted) {
                      // Check mounted after await
                      context
                          .read<ReceiptAnalysisCubit>()
                          .analyzeFile(pdfFile, ReceiptFormat.pdf);
                    }
                  },
                ),
                _buildScanOptionTile(
                  context: context,
                  icon: Icons.photo_camera_outlined,
                  title: 'Use Camera',
                  onTap: () async {
                    final imgFile = await FilePickerService.instance
                        .pickImage(fromGallery: false);
                    if (imgFile != null && context.mounted) {
                      // Check mounted after await
                      context
                          .read<ReceiptAnalysisCubit>()
                          .analyzeFile(imgFile, ReceiptFormat.image);
                    }
                  },
                ),
                _buildScanOptionTile(
                  context: context,
                  icon: Icons.photo_library_outlined,
                  title: 'From Gallery',
                  onTap: () async {
                    final imgFile = await FilePickerService.instance
                        .pickImage(fromGallery: true);
                    if (imgFile != null && context.mounted) {
                      // Check mounted after await
                      context
                          .read<ReceiptAnalysisCubit>()
                          .analyzeFile(imgFile, ReceiptFormat.image);
                    }
                  },
                ),
                _buildScanOptionTile(
                  context: context,
                  icon: Icons.history_outlined, // History icon for last scan
                  title: 'Use Last Scan Data',
                  onTap: () async {
                    // Check mounted? Not strictly needed for sync code unless cubit call is async
                    context.read<ReceiptAnalysisCubit>().loadLastScan();
                  },
                ),

                // --- Image Preview (Styled) ---
                if (imageFile != null) ...[
                  const SizedBox(height: AppStyle.paddingMedium),
                  ClipRRect(
                    // Add rounded corners
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium),
                    child: Image.file(
                      imageFile,
                      height: 150, // Adjust height as desired
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(
                      height: AppStyle.paddingSmall), // Space after image
                ],

                // --- Error Message (Styled) ---
                if (state is ReceiptAnalysisError)
                  Padding(
                    padding: const EdgeInsets.only(
                        top: AppStyle.paddingMedium,
                        bottom: AppStyle.paddingMedium),
                    child: Text(
                      state.message,
                      style: AppStyle.bodyText.copyWith(
                          color: AppStyle.expenseColor), // Use error color
                      textAlign: TextAlign.center,
                    ),
                  ),
                const SizedBox(
                    height: AppStyle.paddingMedium), // Bottom padding
              ],
            ),
          );
        },
      ),
    );
  }

  // Helper to build styled ListTiles for scan options
  Widget _buildScanOptionTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading:
          Icon(icon, color: AppStyle.primaryColor), // Consistent icon color
      title: Text(title, style: AppStyle.bodyText), // Consistent text style
      onTap: onTap,
      shape: RoundedRectangleBorder(
        // Add shape for tap feedback area
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
      ),
      // Optional: Add subtle padding or visual separation if needed
      // contentPadding: EdgeInsets.symmetric(vertical: AppStyle.paddingSmall / 2),
    );
  }
}
