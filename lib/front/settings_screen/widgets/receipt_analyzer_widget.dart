import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:pvp_projektas/backend/services/mistral_service.dart';
import 'package:pvp_projektas/front/bulk_add_transactions_screen.dart';

class ReceiptAnalyzerWidget extends StatefulWidget {
  const ReceiptAnalyzerWidget({super.key});

  @override
  State<ReceiptAnalyzerWidget> createState() => _ReceiptAnalyzerWidgetState();
}

class _ReceiptAnalyzerWidgetState extends State<ReceiptAnalyzerWidget> {
  final _mistralService = MistralService();
  String _analysisResult = '';
  bool _isLoading = false;
  File? _imageFile;

  Future<void> _captureAndAnalyze(bool fromGallery) async {
    setState(() {
      _isLoading = true;
      _analysisResult = '';
    });

    try {
      final imageFile = fromGallery
          ? await _mistralService.pickImage(fromGallery: true)
          : await _mistralService.pickImage();
      if (imageFile == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No image selected';
        });
        return;
      }

      setState(() {
        _imageFile = imageFile;
      });

      final result = await _mistralService.analyzeImage(imageFile);
      setState(() {
        _analysisResult = result;
      });
    } catch (e) {
      setState(() {
        _analysisResult = 'Error analyzing receipt: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndAnalyzeImage(bool fromGallery) async {
    setState(() {
      _isLoading = true;
      _analysisResult = '';
      _imageFile = null; // Clear any previous image
    });

    try {
      final imageFile =
          await _mistralService.pickImage(fromGallery: fromGallery);
      if (imageFile == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No image selected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No image selected')),
        );
        return;
      }

      final transactionData = await _mistralService
          .analyzeAndFormatImage(imageFile, useSavedData: false);
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
        _analysisResult = 'Error analyzing image: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _pickAndAnalyzePDF() async {
    setState(() {
      _isLoading = true;
      _analysisResult = '';
      _imageFile = null; // Clear any previous image
    });

    try {
      final pdfFile = await _mistralService.pickPDF();
      if (pdfFile == null) {
        setState(() {
          _isLoading = false;
          _analysisResult = 'No PDF selected';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('No PDF selected')),
        );
        return;
      }

      final transactionData = await _mistralService.analyzeAndFormatPDF(pdfFile,
          useSavedData: false);
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
        _analysisResult = 'Error analyzing PDF: $e';
      });
    } finally {
      setState(() {
        _isLoading = false;
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
      setState(() {
        _analysisResult = const JsonEncoder.withIndent('  ').convert(savedData);
      });
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) =>
              BulkAddTransactionsScreen(transactionData: savedData!),
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
