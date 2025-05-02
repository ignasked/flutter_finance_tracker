import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/receipt_format.dart';
import 'package:path_provider/path_provider.dart';

part 'receipt_analysis_state.dart';

class ReceiptAnalysisCubit extends Cubit<ReceiptAnalysisState> {
  final MistralService _mistralService;
  final CategoryRepository _categoryRepository;

  ReceiptAnalysisCubit(this._mistralService, this._categoryRepository)
      : super(ReceiptAnalysisInitial());

  Future<void> analyzeFile(File file, ReceiptFormat format) async {
    emit(ReceiptAnalysisLoading());

    try {
      // final categoryNames =
      //     await _categoryRepository.getEnabledCategoryTitles();
      final availableCategories =
          await _categoryRepository.getEnabledCategories();
      final categoryNames =
          availableCategories.map((category) => category.title).toString();

      final receiptJson = await _mistralService
          .processReceiptAndExtractTransactions(file, format, categoryNames);

      // Convert string categories to category IDs before validation
      for (final transaction in receiptJson['transactions']) {
        try {
          final category = availableCategories
              .firstWhere((cat) => cat.title == transaction['category']);
          transaction['categoryId'] = category.id;
        } catch (e) {
          transaction['categoryId'] = Defaults().defaultCategory.id;
        }
      }

      final receiptData = await _validateJSONAndExtractData(receiptJson);
      emit(ReceiptAnalysisSuccess(receiptData));
    } catch (e) {
      emit(ReceiptAnalysisError('Error analyzing file: $e'));
    }
  }

  Future<void> loadLastScan() async {
    emit(ReceiptAnalysisLoading());

    try {
      final availableCategories =
          await _categoryRepository.getEnabledCategories();

      final receiptJson = await _mistralService.loadSavedApiOutput();
      if (receiptJson == null) {
        emit(ReceiptAnalysisError('No saved scan found.'));
        return;
      }

      // Convert string categories to category IDs before validation
      for (final transaction in receiptJson['transactions']) {
        try {
          final category = availableCategories
              .firstWhere((cat) => cat.title == transaction['category']);
          transaction['category_od'] = category.id;
        } catch (e) {
          transaction['category_id'] = Defaults().defaultCategory.id;
        }
      }

      final receiptData = await _validateJSONAndExtractData(receiptJson);
      emit(ReceiptAnalysisSuccess(receiptData));
    } catch (e) {
      emit(ReceiptAnalysisError('Error analyzing file: $e'));
    }
  }

  // Pick an image from the gallery or camera
  Future<File?> pickImage({bool fromGallery = false}) async {
    final picker = ImagePicker();
    final XFile? image = await picker.pickImage(
        source: fromGallery ? ImageSource.gallery : ImageSource.camera,
        imageQuality: 100,
        preferredCameraDevice: CameraDevice.rear);

    if (image == null) return null;

    final bytes = await image.readAsBytes();
    final compressedBytes = await FlutterImageCompress.compressWithList(
      bytes,
      quality: 95,
      format: CompressFormat.jpeg,
    );

    final tempDir = await getTemporaryDirectory();
    final tempFile = File('${tempDir.path}/compressed_receipt.jpg');
    await tempFile.writeAsBytes(compressedBytes);

    return tempFile;
  }

  Future<Map<String, dynamic>> _validateJSONAndExtractData(
      Map<String, dynamic> json) async {
    // Validate and extract receipt metadata with proper type checking
    final transactionName = json['transactionName'] is String
        ? json['transactionName'] as String
        : 'Unnamed Transaction';

    final date = _parseDate(json['date']);

    final totalAmount = json['totalAmountPaid'] is num
        ? (json['totalAmountPaid'] as num).toDouble()
        : 0.0;

    // Safely handle transactions list
    List<Transaction> transactions = [];
    if (json['transactions'] is List) {
      final transactionsList = json['transactions'] as List;

      // Debug the transaction items
      print('Transaction list items count: ${transactionsList.length}');

      // Get all categories for lookup
      final availableCategories =
          await _categoryRepository.getEnabledCategories();
      final defaultCategory = Defaults().defaultCategory;

      for (var item in transactionsList) {
        try {
          if (item is Map<String, dynamic>) {
            final transactionData = item;

            // Find the corresponding category
            Category categoryToUse = defaultCategory;

            // Try to find by category ID first
            if (transactionData['category_id'] is int) {
              final categoryId = transactionData['category_id'] as int;
              final matchingCategory = availableCategories
                  .where((cat) => cat.id == categoryId)
                  .firstOrNull;

              if (matchingCategory != null) {
                categoryToUse = matchingCategory;
                print('Found category by ID: ${categoryToUse.title}');
              }
            }
            // Try to find by category name if ID not found
            else if (transactionData['category'] is String) {
              final categoryName = transactionData['category'] as String;
              final matchingCategory = availableCategories
                  .where((cat) =>
                      cat.title.toLowerCase() == categoryName.toLowerCase())
                  .firstOrNull;

              if (matchingCategory != null) {
                categoryToUse = matchingCategory;
                print('Found category by name: ${categoryToUse.title}');
              } else {
                print(
                    'Could not find category for: $categoryName - using default');
              }
            }

            // Create the transaction with proper category already assigned
            final transaction = Transaction(
              title: transactionData['title'] is String
                  ? transactionData['title'] as String
                  : 'Unnamed Item',
              amount: transactionData['amount'] is num
                  ? (transactionData['amount'] as num).toDouble()
                  : 0.0,
              date: date, // Use the receipt date
              category: categoryToUse,
            );

            transactions.add(transaction);
          }
        } catch (e) {
          print('Error converting transaction: $e');
          // Continue with next transaction
        }
      }

      print('Valid transactions after conversion: ${transactions.length}');
    }

    return {
      'transactionName': transactionName,
      'date': date,
      'totalAmountPaid': totalAmount,
      'transactions': transactions,
    };
  }

  DateTime _parseDate(dynamic date) {
    try {
      return date != null ? DateTime.parse(date.toString()) : DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }
}
