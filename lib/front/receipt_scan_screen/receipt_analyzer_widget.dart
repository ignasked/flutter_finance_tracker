import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/file_picker_service.dart';
import 'package:money_owl/backend/utils/receipt_format.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
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
    return BlocProvider(
      create: (context) => ReceiptAnalysisCubit(
        MistralService.instance,
        context.read<CategoryRepository>(),
      ),
      child: BlocConsumer<ReceiptAnalysisCubit, ReceiptAnalysisState>(
        listener: (context, state) async {
          if (state is ReceiptAnalysisLoading) {
            showLoadingPopup(context,
                message: 'Analyzing receipt. Please wait...');
          } else {
            hideLoadingPopup(context);
          }

          if (state is ReceiptAnalysisError) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.message)),
            );
          } else if (state is ReceiptAnalysisSuccess) {
            final receiptData = state.receiptData;
            final transactions = await Navigator.push(
              context,
              MaterialPageRoute(
                builder: (context) => BulkAddTransactionsScreen(
                  transactionName: receiptData['transactionName'],
                  date: receiptData['date'],
                  totalExpensesFromReceipt: receiptData['totalAmountPaid'],
                  transactions: receiptData['transactions'],
                ),
              ),
            );
            if (transactions != null) {
              context
                  .read<AccountTransactionCubit>()
                  .addTransactions(transactions as List<Transaction>);
            }
          }
        },
        builder: (context, state) {
          final imageFile =
              state is ReceiptAnalysisImageSelected ? state.imageFile : null;

          return Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  ListTile(
                    leading: const Icon(Icons.picture_as_pdf),
                    title: const Text('From PDF (Recommended)'),
                    onTap: () async {
                      final pdfFile =
                          await FilePickerService.instance.pickPDF();
                      if (pdfFile != null) {
                        context
                            .read<ReceiptAnalysisCubit>()
                            .analyzeFile(pdfFile, ReceiptFormat.pdf);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_camera),
                    title: const Text('Scan Photo'),
                    onTap: () async {
                      final imageFile = await FilePickerService.instance
                          .pickImage(fromGallery: false);
                      if (imageFile != null) {
                        await context
                            .read<ReceiptAnalysisCubit>()
                            .analyzeFile(imageFile, ReceiptFormat.image);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.photo_library),
                    title: const Text('From Gallery'),
                    onTap: () async {
                      final imageFile = await FilePickerService.instance
                          .pickImage(fromGallery: true);
                      if (imageFile != null) {
                        await context
                            .read<ReceiptAnalysisCubit>()
                            .analyzeFile(imageFile, ReceiptFormat.image);
                      }
                    },
                  ),
                  ListTile(
                    leading: const Icon(Icons.save),
                    title: const Text('Last Scan'),
                    onTap: () async {
                      await context.read<ReceiptAnalysisCubit>().loadLastScan();
                    },
                  ),
                  if (imageFile != null) ...[
                    const SizedBox(height: 16),
                    Image.file(
                      imageFile,
                      height: 200,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ],
                  if (state is ReceiptAnalysisError)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Text(state.message),
                    ),
                ],
              ));
        },
      ),
    );
  }
}
