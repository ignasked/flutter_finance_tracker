import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_image_compress/flutter_image_compress.dart';
import 'package:image_picker/image_picker.dart';
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
      final categoryNames = _categoryRepository.getEnabledCategoryTitles();
      final availableCategories = _categoryRepository.getEnabledCategories();

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

      final receiptData = _validateJSONAndExtractData(receiptJson);
      emit(ReceiptAnalysisSuccess(receiptData));
    } catch (e) {
      emit(ReceiptAnalysisError('Error analyzing file: $e'));
    }
  }

  Future<void> loadLastScan() async {
    emit(ReceiptAnalysisLoading());

    try {
      final categoryNames = _categoryRepository.getEnabledCategoryTitles();
      final availableCategories = _categoryRepository.getEnabledCategories();

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
          transaction['categoryId'] = category.id;
        } catch (e) {
          transaction['categoryId'] = Defaults().defaultCategory.id;
        }
      }

      final receiptData = _validateJSONAndExtractData(receiptJson);
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

  Map<String, dynamic> _validateJSONAndExtractData(Map<String, dynamic> json) {
    final transactionName = json['transactionName'] ?? 'Unnamed Transaction';
    final date = _parseDate(json['date']);
    final totalAmount = json['totalAmount'] ?? 0.0;

    final transactions = (json['transactions'] as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map((transaction) => Transaction.fromJson(
            transaction, _categoryRepository))
        .toList();

    for (final transaction in transactions) {
      transaction.copyWith(date: date);
    }

    return {
      'transactionName': transactionName,
      'date': date,
      'totalAmount': totalAmount,
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
