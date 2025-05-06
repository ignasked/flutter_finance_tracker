import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/account_repository.dart'; // Import AccountRepository
import 'package:money_owl/backend/services/file_picker_service.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/receipt_format.dart';
import 'package:money_owl/front/common/loading_widget.dart';
import 'package:money_owl/front/receipt_scan/bulk_add/bulk_add_transactions_screen.dart';
import 'package:money_owl/front/receipt_scan/receipt_analyzer/cubit/receipt_analysis_cubit.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';

class ReceiptAnalyzerButton extends StatelessWidget {
  final VoidCallback onTap;

  const ReceiptAnalyzerButton({Key? key, required this.onTap})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ListTile(
      leading:
          const Icon(Icons.receipt_long_outlined, color: AppStyle.primaryColor),
      title: const Text('Scan Receipt', style: AppStyle.titleStyle),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
      ),
      onTap: onTap,
    );
  }
}

class ReceiptAnalyzerWidget extends StatelessWidget {
  const ReceiptAnalyzerWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReceiptAnalysisCubit(
        MistralService.instance,
        context.read<CategoryRepository>(),
      ),
      child: BlocConsumer<ReceiptAnalysisCubit, ReceiptAnalysisState>(
        listener: (context, state) async {
          // Handle loading state
          if (state is ReceiptAnalysisLoading) {
            showLoadingPopup(context, message: 'Analyzing receipt...');
          } else {
            hideLoadingPopup(context);
          }

          // Handle error state
          if (state is ReceiptAnalysisError) {
            _showErrorSnackbar(context, state.message);
          }
          // Handle success state
          else if (state is ReceiptAnalysisSuccess) {
            // Ensure context is valid before proceeding
            if (!context.mounted) return;

            await _handleSuccessfulAnalysis(context, state.receiptData);
          }
        },
        builder: (context, state) {
          return _buildScanOptionsSheet(context, state);
        },
      ),
    );
  }

  // Handle successful receipt analysis
  Future<void> _handleSuccessfulAnalysis(
      BuildContext context, Map<String, dynamic> receiptData) async {
    // Extract the transactions from the receipt data
    final transactions = receiptData['transactions'] is List
        ? (receiptData['transactions'] as List)
            .whereType<Transaction>()
            .toList()
        : <Transaction>[];

    if (transactions.isEmpty) {
      _showErrorSnackbar(context, 'No items found in this receipt');
      return;
    }

    // Get repositories to pass to BulkAdd screen
    final categoryRepo = context.read<CategoryRepository>();
    final accountRepo = context.read<AccountRepository>();

    // Navigate to the bulk add transactions screen
    final addedTransactions = await Navigator.push<List<Transaction>?>(
      context,
      MaterialPageRoute(
        builder: (_) => BulkAddTransactionsScreen(
          transactionName:
              receiptData['transactionName'] as String? ?? "Unknown Store",
          date: receiptData['date'] as DateTime? ?? DateTime.now(),
          totalExpensesFromReceipt:
              (receiptData['totalAmountPaid'] as num?)?.toDouble() ?? 0.0,
          transactions: transactions,
          categoryRepository: categoryRepo,
          accountRepository: accountRepo,
        ),
      ),
    );

    // Ensure context is still valid after navigation
    if (!context.mounted) return;

    // Add transactions if the user confirmed
    if (addedTransactions != null && addedTransactions.isNotEmpty) {
      // Add to repository through TransactionsCubit
      await context
          .read<DataManagementCubit>()
          .addTransactions(addedTransactions);

      // Show success message
      _showSuccessSnackbar(context, addedTransactions.length);

      // Close the bottom sheet
      Navigator.pop(context);
    }
  }

  // Build the scan options sheet
  Widget _buildScanOptionsSheet(
      BuildContext context, ReceiptAnalysisState state) {
    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
        left: AppStyle.paddingMedium,
        right: AppStyle.paddingMedium,
        top: AppStyle.paddingSmall,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 5,
              margin: const EdgeInsets.only(bottom: AppStyle.paddingMedium),
              decoration: BoxDecoration(
                color: AppStyle.dividerColor.withOpacity(0.5),
                borderRadius: BorderRadius.circular(AppStyle.borderRadiusSmall),
              ),
            ),
          ),

          // Title
          const Padding(
            padding: EdgeInsets.only(bottom: AppStyle.paddingMedium),
            child: Text(
              'Add Receipt',
              style: AppStyle.titleStyle,
              textAlign: TextAlign.center,
            ),
          ),

          // Scan options cards
          _buildScanOptionCard(
            context: context,
            icon: Icons.picture_as_pdf_outlined,
            title: 'PDF Receipt',
            subtitle: 'Select a PDF file from your device',
            onTap: () => _handlePdfSelection(context),
          ),

          const SizedBox(height: AppStyle.paddingSmall),

          _buildScanOptionCard(
            context: context,
            icon: Icons.photo_camera_outlined,
            title: 'Camera',
            subtitle: 'Take a photo of your receipt',
            onTap: () => _handleCameraSelection(context),
          ),

          const SizedBox(height: AppStyle.paddingSmall),

          _buildScanOptionCard(
            context: context,
            icon: Icons.photo_library_outlined,
            title: 'Gallery',
            subtitle: 'Select an image from your gallery',
            onTap: () => _handleGallerySelection(context),
          ),

          const SizedBox(height: AppStyle.paddingSmall),

          _buildScanOptionCard(
            context: context,
            icon: Icons.history_outlined,
            title: 'Previous Scan',
            subtitle: 'Use data from your last scan',
            onTap: () => _handlePreviousScan(context),
          ),

          // Error message
          if (state is ReceiptAnalysisError)
            Padding(
              padding:
                  const EdgeInsets.symmetric(vertical: AppStyle.paddingMedium),
              child: Text(
                state.message,
                style: AppStyle.captionStyle
                    .copyWith(color: AppStyle.expenseColor),
                textAlign: TextAlign.center,
              ),
            ),

          const SizedBox(height: AppStyle.paddingMedium),
        ],
      ),
    );
  }

  // Build a scan option card
  Widget _buildScanOptionCard({
    required BuildContext context,
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return Card(
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
      ),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
        child: Padding(
          padding: const EdgeInsets.all(AppStyle.paddingMedium),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppStyle.primaryColor.withOpacity(0.1),
                  borderRadius:
                      BorderRadius.circular(AppStyle.borderRadiusMedium),
                ),
                child: Icon(icon, color: AppStyle.primaryColor),
              ),
              const SizedBox(width: AppStyle.paddingMedium),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppStyle.subtitleStyle),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppStyle.captionStyle,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right,
                  color: AppStyle.textColorSecondary),
            ],
          ),
        ),
      ),
    );
  }

  // Handler methods for different scan options
  void _handlePdfSelection(BuildContext context) async {
    final pdfFile = await FilePickerService.instance.pickPDF();
    if (pdfFile != null && context.mounted) {
      context
          .read<ReceiptAnalysisCubit>()
          .analyzeFile(pdfFile, ReceiptFormat.pdf);
    }
  }

  void _handleCameraSelection(BuildContext context) async {
    final imgFile =
        await FilePickerService.instance.pickImage(fromGallery: false);
    if (imgFile != null && context.mounted) {
      context
          .read<ReceiptAnalysisCubit>()
          .analyzeFile(imgFile, ReceiptFormat.image);
    }
  }

  void _handleGallerySelection(BuildContext context) async {
    final imgFile =
        await FilePickerService.instance.pickImage(fromGallery: true);
    if (imgFile != null && context.mounted) {
      context
          .read<ReceiptAnalysisCubit>()
          .analyzeFile(imgFile, ReceiptFormat.image);
    }
  }

  void _handlePreviousScan(BuildContext context) {
    context.read<ReceiptAnalysisCubit>().loadLastScan();
  }

  // Show error snackbar
  void _showErrorSnackbar(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message,
              style: AppStyle.bodyText.copyWith(color: ColorPalette.onError)),
          backgroundColor: ColorPalette.errorContainer,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
          margin: const EdgeInsets.all(AppStyle.paddingSmall),
        ),
      );
  }

  // Show success snackbar
  void _showSuccessSnackbar(BuildContext context, int count) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            '$count transactions added!',
            style: AppStyle.bodyText.copyWith(color: ColorPalette.onPrimary),
          ),
          backgroundColor: AppStyle.incomeColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
          margin: const EdgeInsets.all(AppStyle.paddingSmall),
        ),
      );
  }
}
