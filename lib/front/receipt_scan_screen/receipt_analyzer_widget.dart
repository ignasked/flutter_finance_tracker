import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/services/file_picker_service.dart';
import 'package:money_owl/front/receipt_scan_screen/bulk_add_transactions_screen.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/backend/utils/receipt_format.dart';
import 'package:money_owl/front/common/loading_widget.dart';

class ReceiptAnalyzerWidget extends StatefulWidget {
  const ReceiptAnalyzerWidget({super.key});

  @override
  State<ReceiptAnalyzerWidget> createState() => _ReceiptAnalyzerWidgetState();
}

class _ReceiptAnalyzerWidgetState extends State<ReceiptAnalyzerWidget> {
  final _mistralService = MistralService.instance;
  final _filePickerService = FilePickerService.instance;
  String _analysisResult = '';
  File? _imageFile;

//TODO: remove loadSavedResponse parameter from _analyzeFile method
  Future<void> _analyzeFile(File file, ReceiptFormat format,
      {bool? loadSavedResponse}) async {
    showLoadingPopup(context, message: 'Analyzing receipt. Please wait...');

    try {
      final categoryRepository = context.read<CategoryRepository>();
      final availableCategories = categoryRepository.getEnabledCategories();
      final categoryIdNamePairs = availableCategories
          .map((category) => '${category.id}:${category.title}')
          .join(', ');

      Map<String, dynamic>? receiptJson;

      //TODO: remove loadSavedResponse parameter from _analyzeFile method
      if (loadSavedResponse == true) {
        // Load saved data from the Mistral service
        receiptJson = await _mistralService.loadSavedApiOutput();
        if (receiptJson == null) {
          setState(() {
            _analysisResult = 'No saved data found';
          });
          return;
        }
        // Process the saved data as needed
      } else {
        receiptJson =
            await _mistralService.processReceiptAndExtractTransactions(
                file, format, categoryIdNamePairs);
      }
      if (!mounted) return; // Check if the widget is still mounted

      final receiptData =
          _validateJSONAndExtractData(receiptJson, categoryRepository);

      final transactionName = receiptData['transactionName'];
      final transactions = receiptData['transactions'] as List<Transaction>;

      final newTransactions = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BulkAddTransactionsScreen(
            transactionName: transactionName,
            transactions: transactions,
          ),
        ),
      );

      if (!mounted) return; // Check if the widget is still mounted

      if (newTransactions != null) {
        print('New transactions: $newTransactions');
        final txCubit = context.read<AccountTransactionCubit>();
        txCubit.addTransactions(newTransactions);
      }
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _analysisResult = 'Error analyzing file: $e';
      });
    } finally {
      hideLoadingPopup(context);
    }
  }

  // Validate and extract data from the JSON response
  Map<String, dynamic> _validateJSONAndExtractData(
      Map<String, dynamic> json, CategoryRepository categoryRepository) {
    // Extract transactionName
    final transactionName = json['transactionName'] ?? 'Unnamed Transaction';

    // Extract and validate transactions
    final transactions = (json['transactions'] as List<dynamic>)
        .where((transaction) => transaction is Map<String, dynamic>)
        .map((transaction) => Transaction.fromJson(
            transaction as Map<String, dynamic>, categoryRepository))
        .toList();

    return {
      'transactionName': transactionName,
      'transactions': transactions,
    };
  }

  Future<void> _pickAndAnalyzeImage(bool fromGallery) async {
    try {
      final imageFile =
          await _filePickerService.pickImage(fromGallery: fromGallery);
      if (!mounted) return; // Check if the widget is still mounted

      if (imageFile == null) {
        setState(() {
          _analysisResult = 'No image selected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No image selected')),
        );
        return;
      }

      setState(() {
        _imageFile = imageFile;
      });

      await _analyzeFile(imageFile, ReceiptFormat.image);
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _analysisResult = 'Error picking or analyzing image: $e';
      });
    }
  }

  Future<void> _pickAndAnalyzePDF() async {
    try {
      final pdfFile = await _filePickerService.pickPDF();
      if (!mounted) return; // Check if the widget is still mounted

      if (pdfFile == null) {
        setState(() {
          _analysisResult = 'No PDF selected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No PDF selected')),
        );
        return;
      }

      await _analyzeFile(pdfFile, ReceiptFormat.pdf);
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _analysisResult = 'Error picking or analyzing PDF: $e';
      });
    }
  }

  Future<void> _loadSavedData() async {
    showLoadingPopup(context, message: 'Loading saved data...');

    try {
      final savedData = await _mistralService.loadSavedApiOutput();
      if (!mounted) return; // Check if the widget is still mounted

      print('Saved data: $savedData');
      if (savedData == null) {
        setState(() {
          _analysisResult = 'No saved data found';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved data found')),
        );
        return;
      }

      // Extract transactionName
      final transactionName =
          savedData['transactionName'] ?? 'Unnamed Transaction';

      // Convert transactions using Transaction.fromJson
      if (savedData['transactions'] is! List) {
        throw Exception('Invalid transactions data: Expected a list');
      }

      final transactions = (savedData['transactions'] as List<dynamic>)
          .map((transaction) => Transaction.fromJson(
              transaction as Map<String, dynamic>,
              context.read<CategoryRepository>()))
          .toList();

      if (!mounted) return; // Check if the widget is still mounted

      // Navigate to BulkAddTransactionsScreen
      final newTransactions = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BulkAddTransactionsScreen(
            transactionName: transactionName,
            transactions: transactions,
          ),
        ),
      );

      if (!mounted) return; // Check if the widget is still mounted

      if (newTransactions != null) {
        print('New transactions: $newTransactions');
        final txCubit = context.read<AccountTransactionCubit>();
        txCubit.addTransactions(newTransactions);
      }
    } catch (e) {
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _analysisResult = 'Error loading saved data: $e';
      });
    } finally {
      hideLoadingPopup(context);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // First row of buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: () => _pickAndAnalyzeImage(false),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Receipt'),
            ),
            ElevatedButton.icon(
              onPressed: () => _pickAndAnalyzeImage(true),
              icon: const Icon(Icons.photo_library),
              label: const Text('From Gallery'),
            ),
          ],
        ),
        const SizedBox(height: 16), // Add spacing between rows

        // Second row of buttons
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            ElevatedButton.icon(
              onPressed: _pickAndAnalyzePDF,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('From PDF'),
            ),
            ElevatedButton.icon(
              onPressed: _loadSavedData,
              icon: const Icon(Icons.barcode_reader),
              label: const Text('Load Saved Data'),
            ),
          ],
        ),
        const SizedBox(height: 16), // Add spacing below the buttons

        // Display the image if available
        if (_imageFile != null) ...[
          const SizedBox(height: 16),
          Image.file(
            _imageFile!,
            height: 200,
            width: double.infinity,
            fit: BoxFit.cover,
          ),
        ],

        // Display analysis result
        if (_analysisResult.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_analysisResult),
          ),
      ],
    );
  }
}
