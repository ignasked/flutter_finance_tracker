import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pvp_projektas/backend/services/mistral_service.dart';
import 'package:pvp_projektas/backend/services/file_picker_service.dart';
import 'package:pvp_projektas/front/bulk_add_transactions_screen.dart';
import 'package:pvp_projektas/utils/receipt_format.dart';

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
      final transactionData =
          await _mistralService.analyzeAndFormat(file, format);
      setState(() {
        _analysisResult =
            const JsonEncoder.withIndent('  ').convert(transactionData);
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BulkAddTransactionsScreen(transactionData: transactionData),
        ),
      );
    } catch (e) {
      setState(() {
        _analysisResult = 'Error analyzing file: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndAnalyzeImage(bool fromGallery) async {
    try {
      final imageFile =
          await _filePickerService.pickImage(fromGallery: fromGallery);
      if (imageFile == null) {
        setState(() {
          _isLoading = false;
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
      setState(() {
        _analysisResult = 'Error picking or analyzing image: $e';
      });
    }
  }

  Future<void> _pickAndAnalyzePDF() async {
    try {
      final pdfFile = await _filePickerService.pickPDF();
      if (pdfFile == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No PDF selected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No PDF selected')),
        );
        return;
      }

      await _analyzeFile(pdfFile, ReceiptFormat.pdf);
    } catch (e) {
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
      if (savedData == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No saved data found';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('No saved data found')),
        );
        return;
      }

      setState(() {
        _analysisResult = const JsonEncoder.withIndent('  ').convert(savedData);
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BulkAddTransactionsScreen(transactionData: savedData),
        ),
      );
    } catch (e) {
      setState(() {
        _analysisResult = 'Error loading saved data: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
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
              icon: const Icon(Icons.storage),
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
