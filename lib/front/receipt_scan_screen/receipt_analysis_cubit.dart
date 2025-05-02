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

  /// Analyzes a receipt file (image or PDF) and extracts transactions
  Future<void> analyzeFile(File file, ReceiptFormat format) async {
    emit(ReceiptAnalysisLoading());

    try {
      // Get all available categories for mapping
      final availableCategories =
          await _categoryRepository.getEnabledCategories();
      final categoryNamesString =
          availableCategories.map((category) => category.title).join(', ');

      // Process the receipt with the AI service
      final receiptJson =
          await _mistralService.processReceiptAndExtractTransactions(
              file, format, categoryNamesString);

      // Extract and process the receipt data
      final receiptData =
          await _processReceiptData(receiptJson, availableCategories);

      emit(ReceiptAnalysisSuccess(receiptData));
    } catch (e) {
      emit(ReceiptAnalysisError('Error analyzing receipt: $e'));
    }
  }

  /// Loads the last scan data if available
  Future<void> loadLastScan() async {
    emit(ReceiptAnalysisLoading());

    try {
      final availableCategories =
          await _categoryRepository.getEnabledCategories();
      final receiptJson = await _mistralService.loadSavedApiOutput();

      if (receiptJson == null) {
        emit(ReceiptAnalysisError('No saved scan found'));
        return;
      }

      // Extract and process the receipt data
      final receiptData =
          await _processReceiptData(receiptJson, availableCategories);

      emit(ReceiptAnalysisSuccess(receiptData));
    } catch (e) {
      emit(ReceiptAnalysisError('Error loading last scan: $e'));
    }
  }

  /// Takes a receipt JSON and processes it into a structured map with transactions
  Future<Map<String, dynamic>> _processReceiptData(
      Map<String, dynamic> json, List<Category> availableCategories) async {
    // Extract basic receipt data
    final transactionName = json['transactionName'] is String
        ? json['transactionName'] as String
        : 'Unknown Store';

    final date = _parseDate(json['date']);

    final totalAmount = json['totalAmountPaid'] is num
        ? (json['totalAmountPaid'] as num).toDouble()
        : 0.0;

    // Map to track categories by ID for faster lookup
    final categoryIdMap = {for (var cat in availableCategories) cat.id: cat};

    // Map to track categories by name for faster lookup (case insensitive)
    final categoryNameMap = {
      for (var cat in availableCategories) cat.title.toLowerCase(): cat
    };

    // Process the transactions
    List<Transaction> transactions = [];
    if (json['transactions'] is List) {
      final transactionsList = json['transactions'] as List;

      for (var item in transactionsList) {
        if (item is Map<String, dynamic>) {
          try {
            // Get transaction data
            final title = item['title'] is String
                ? item['title'] as String
                : 'Unnamed Item';

            final amount = item['amount'] is num
                ? (item['amount'] as num).toDouble()
                : 0.0;

            // Find the right category
            Category? category = Defaults().defaultCategory;

            // Try by category ID first
            if (item['categoryId'] is int) {
              final catId = item['categoryId'] as int;
              category = categoryIdMap[catId] ?? category;
            }
            // Try by category name
            else if (item['category'] is String) {
              final catName = (item['category'] as String).toLowerCase();
              category = categoryNameMap[catName] ?? category;
            }

            // Create a transaction with all data in place
            final transaction = Transaction(
              title: title,
              amount: amount,
              date: date,
              category: category,
              // Let the BulkAddTransactionsScreen handle the account assignment
              // Additional metadata can be preserved
              metadata: {'originalJson': item},
            );

            transactions.add(transaction);
          } catch (e) {
            print('Error processing transaction: $e');
            // Continue with the next transaction
          }
        }
      }
    }

    // Return structured receipt data
    return {
      'transactionName': transactionName,
      'date': date,
      'totalAmountPaid': totalAmount,
      'transactions': transactions,
    };
  }

  /// Helper method to parse a date from various formats
  DateTime _parseDate(dynamic date) {
    try {
      if (date == null) {
        return DateTime.now();
      }

      if (date is String) {
        return DateTime.parse(date);
      }

      if (date is DateTime) {
        return date;
      }

      return DateTime.now();
    } catch (e) {
      return DateTime.now();
    }
  }

  /// Helper method to pick an image from camera or gallery
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
}
