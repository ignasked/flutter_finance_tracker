import 'dart:io';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';
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
      final availableCategories =
          await _categoryRepository.getEnabledCategories();
      final categoryNamesString =
          availableCategories.map((category) => category.title).join(', ');

      final receiptJson =
          await _mistralService.processReceiptAndExtractTransactions(
              file, format, categoryNamesString);

      final receiptData =
          await _processReceiptDataInternal(receiptJson, availableCategories);

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

      final receiptData =
          await _processReceiptDataInternal(receiptJson, availableCategories);

      emit(ReceiptAnalysisSuccess(receiptData));
    } catch (e) {
      emit(ReceiptAnalysisError('Error loading last scan: $e'));
    }
  }

  /// Internal method to process JSON and create Transaction objects
  Future<Map<String, dynamic>> _processReceiptDataInternal(
      Map<String, dynamic> json, List<Category> availableCategories) async {
    try {
      final transactionName = json['transactionName'] is String
          ? json['transactionName'] as String
          : 'Unknown Store';
      final date = _parseDate(json['date']);
      final totalAmountPaid = json['totalAmountPaid'] is num
          ? -(json['totalAmountPaid'] as num).toDouble()
          : 0.0;

      final categoryIdMap = {for (var cat in availableCategories) cat.id: cat};
      final categoryNameMap = {
        for (var cat in availableCategories) cat.title.toLowerCase(): cat
      };

      List<Transaction> transactions = [];
      if (json['transactions'] is List) {
        final transactionsList = json['transactions'] as List;
        for (var item in transactionsList) {
          if (item is Map<String, dynamic>) {
            try {
              final title = item['title'] is String
                  ? item['title'] as String
                  : 'Unknown Item';
              double amount = item['amount'] is num
                  ? (((item['amount'] as num).toDouble() * 100).round() / 100)
                  : 0.0;

              Category? category;
              if (item['categoryId'] is int) {
                category = categoryIdMap[item['categoryId'] as int];
              }
              if (category == null && item['category'] is String) {
                category =
                    categoryNameMap[(item['category'] as String).toLowerCase()];
              }
              category ??= Defaults().defaultCategory;

              // --- Adjust amount sign based on category type ---
              if (category.type == TransactionType.income && amount < 0) {
                amount = -amount; // Make income positive
              } else if (category.type == TransactionType.expense &&
                  amount > 0) {
                amount = -amount; // Make expense negative
              }

              final transaction = Transaction.createWithIds(
                title: title,
                amount: amount,
                date: date,
                categoryId: category.id,
                fromAccountId: Defaults().defaultAccount.id,
                metadata: {'originalJson': item},
              );
              transactions.add(transaction);
            } catch (e) {
              print('Error processing transaction item: $e');
            }
          }
        }
      }

      final result = {
        'transactionName': transactionName,
        'date': date,
        'totalAmountPaid': totalAmountPaid,
        'transactions': transactions,
      };

      return result;
    } catch (e) {
      print('Error in _processReceiptDataInternal: $e');
      throw Exception('Failed to process receipt data: $e');
    }
  }

  /// Helper method to parse a date from various formats, defaults to now()
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (_) {
        print(
            "Warning: Failed to parse date string '$dateValue', using now().");
        return DateTime.now();
      }
    } else if (dateValue is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } catch (_) {
        print(
            "Warning: Failed to parse date from int '$dateValue', using now().");
        return DateTime.now();
      }
    }

    print(
        "Warning: Unrecognized date format for value '$dateValue', using now().");
    return DateTime.now();
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
