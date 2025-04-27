import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/services/file_picker_service.dart';
import 'package:money_owl/front/bulk_add_transactions_screen.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/utils/receipt_format.dart';

class ReceiptAnalyzerWidget extends StatefulWidget {
  const ReceiptAnalyzerWidget({super.key});

  @override
  State<ReceiptAnalyzerWidget> createState() => _ReceiptAnalyzerWidgetState();
}

class _ReceiptAnalyzerWidgetState extends State<ReceiptAnalyzerWidget> {
  final _mistralService = MistralService.instance;
  final _filePickerService = FilePickerService.instance;
  String _analysisResult = '';
  bool _isLoading = false;
  File? _imageFile;

  Future<void> _analyzeFile(File file, ReceiptFormat format) async {
    setState(() {
      _isLoading = true;
      _analysisResult = '';
      _imageFile = null; // Clear any previous image
    });

    try {
      String categoryTitles = context
          .read<CategoryRepository>()
          .getEnabledCategoryTitles(); // Load categories

      final receiptJson =
          await _mistralService.analyzeAndFormat(file, format, categoryTitles);

      if (!mounted) return; // Check if the widget is still mounted

      setState(() {
        _analysisResult = const JsonEncoder.withIndent('  ').convert({
          'transactionName': receiptJson['transactionName'],
          'transactions': (receiptJson['transactions'] as List<Transaction>)
              .map((t) => t.toJson())
              .toList(),
        });
      });

      final newTransactions = await Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => BulkAddTransactionsScreen(
            transactionName: receiptJson['transactionName'],
            transactions: receiptJson['transactions'] as List<Transaction>,
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
      setState(() {
        _isLoading = false;
      });
      Navigator.pop(context); // Close the bottom sheet
    }
  }

  Future<void> _pickAndAnalyzeImage(bool fromGallery) async {
    try {
      final imageFile =
          await _filePickerService.pickImage(fromGallery: fromGallery);
      if (!mounted) return; // Check if the widget is still mounted

      if (imageFile == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No image selected';
        });
        if (!mounted) return; // Check if the widget is still mounted
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
          _isLoading = false;
          _analysisResult = 'No PDF selected';
        });
        if (!mounted) return; // Check if the widget is still mounted
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
    setState(() {
      _isLoading = true;
      _analysisResult = '';
      _imageFile = null; // Clear any previous image
    });

    try {
      final savedData = await _mistralService.loadSavedApiOutput();
      if (!mounted) return; // Check if the widget is still mounted

      print('Saved data: $savedData');
      if (savedData == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No saved data found';
        });
        if (!mounted) return; // Check if the widget is still mounted
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
          .map((transaction) =>
              Transaction.fromJson(transaction as Map<String, dynamic>))
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
      if (!mounted) return; // Check if the widget is still mounted
      setState(() {
        _isLoading = false;
      });
      Navigator.pop(context); // Close the bottom sheet
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
              onPressed: _isLoading ? null : () => _pickAndAnalyzeImage(false),
              icon: const Icon(Icons.camera_alt),
              label: const Text('Scan Receipt'),
            ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : () => _pickAndAnalyzeImage(true),
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
              onPressed: _isLoading ? null : _pickAndAnalyzePDF,
              icon: const Icon(Icons.picture_as_pdf),
              label: const Text('From PDF'),
            ),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _loadSavedData,
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

        // Display loading indicator or analysis result
        if (_isLoading)
          const CircularProgressIndicator()
        else if (_analysisResult.isNotEmpty)
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: Text(_analysisResult),
          ),
      ],
    );
  }
}
