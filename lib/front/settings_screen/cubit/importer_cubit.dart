import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/repositories/account_repository.dart'; // Import AccountRepository
import 'package:money_owl/backend/repositories/category_repository.dart'; // Import CategoryRepository
import 'package:money_owl/backend/repositories/transaction_repository.dart'; // Import TransactionRepository
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart'; // Import DataManagementCubit
import 'package:path_provider/path_provider.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/utils/defaults.dart';

part 'importer_state.dart';

/// Simple class to hold import results
class _ImportResult {
  final List<Transaction> transactions;
  final int errorCount;

  _ImportResult({
    required this.transactions,
    required this.errorCount,
  });
}

/// A Cubit for handling all import and export operations in the app
/// Handles JSON data parsing, file I/O, and transaction conversion
class ImporterCubit extends Cubit<ImporterState> {
  ImporterCubit() : super(const ImporterState());

  /// Exports transactions to a JSON file
  Future<String> exportTransactions(List<Transaction> transactions) async {
    int errorCount = 0;
    int successCount = 0;

    try {
      emit(state.copyWith(isLoading: true));

      // Generate JSON data with error handling
      final jsonData = generateJSONData(transactions);

      // Count errors and successful exports
      final jsonList = jsonDecode(jsonData) as List;
      for (var item in jsonList) {
        if (item is Map<String, dynamic> && item.containsKey('exportError')) {
          errorCount++;
        } else {
          successCount++;
        }
      }

      final filePath = await writeToJSON(jsonData);

      // Create appropriate success/warning message
      String message;
      if (errorCount > 0) {
        message =
            'Exported $successCount transactions with $errorCount errors to $filePath. Some transactions may be missing relation data.';
        emit(state.copyWith(
          isLoading: false,
          exportPath: filePath,
          lastOperation: message,
          error:
              'Some transactions had errors during export. Check log for details.',
        ));
      } else {
        message =
            'Successfully exported $successCount transactions to $filePath';
        emit(state.copyWith(
          isLoading: false,
          exportPath: filePath,
          lastOperation: message,
        ));
      }

      return filePath;
    } catch (e) {
      final errorMsg = 'Export failed: ${e.toString()}';
      emit(state.copyWith(
        isLoading: false,
        error: errorMsg,
        lastOperation: errorMsg,
      ));
      return '';
    }
  }

  /// Imports transactions from a JSON file
  Future<List<Transaction>?> importTransactions(
    List<Transaction> existingTransactions,
    bool includeDuplicates, {
    List<Category>? availableCategories,
    List<Account>? availableAccounts,
  }) async {
    try {
      emit(state.copyWith(isLoading: true));

      // Make sure we have the necessary file
      if (!await _checkImportFileExists()) {
        emit(state.copyWith(
          isLoading: false,
          error: 'Import file not found. Please export transactions first.',
          lastOperation: 'Import failed: File not found',
        ));
        return null;
      }

      final data = await readJSON();
      List<Transaction> newTransactions;
      int errorCount = 0;

      // If we have available categories/accounts, use enhanced import that preserves relations
      if ((availableCategories != null && availableCategories.isNotEmpty) ||
          (availableAccounts != null && availableAccounts.isNotEmpty)) {
        final result = await _importTransactionsWithRelations(
          data,
          availableCategories ?? [],
          availableAccounts ?? [],
        );
        newTransactions = result.transactions;
        errorCount = result.errorCount;
      } else {
        // Fallback to standard import (may lose relations)
        try {
          newTransactions = fromJSONToTransactions(data);
        } catch (e) {
          emit(state.copyWith(
            isLoading: false,
            error: 'Failed to parse import data: ${e.toString()}',
            lastOperation: 'Import failed due to parsing error',
          ));
          return null;
        }
      }

      // Find duplicates by comparing IDs
      final existingIds = existingTransactions.map((tx) => tx.id).toSet();
      final duplicates =
          newTransactions.where((tx) => existingIds.contains(tx.id)).toList();

      if (duplicates.isNotEmpty && !includeDuplicates) {
        emit(state.copyWith(
          isLoading: false,
          duplicates: duplicates,
          lastOperation: 'Found ${duplicates.length} duplicate transactions',
        ));
        return null;
      }

      final filteredTransactions = includeDuplicates
          ? newTransactions
          : newTransactions
              .where((tx) => !existingIds.contains(tx.id))
              .toList();

      // Create appropriate message based on success and error count
      String message;
      if (errorCount > 0) {
        message =
            'Imported ${filteredTransactions.length} transactions with $errorCount errors. Some transactions may have incomplete data.';
        emit(state.copyWith(
          isLoading: false,
          duplicates: [],
          lastOperation: message,
          error:
              'Some transactions had errors during import. Check log for details.',
        ));
      } else {
        message =
            'Successfully imported ${filteredTransactions.length} transactions';
        emit(state.copyWith(
          isLoading: false,
          duplicates: [],
          lastOperation: message,
        ));
      }

      return filteredTransactions;
    } catch (e) {
      final errorMsg = 'Import failed: ${e.toString()}';
      emit(state.copyWith(
        isLoading: false,
        error: errorMsg,
        lastOperation: errorMsg,
      ));
      return null;
    }
  }

  /// Deletes all user-specific data (transactions, custom categories, custom accounts)
  /// and resets to default categories and accounts.
  Future<void> deleteAllData(
    TransactionRepository txRepo,
    CategoryRepository catRepo,
    AccountRepository accRepo,
    DataManagementCubit dataCubit,
  ) async {
    emit(state.copyWith(isLoading: true, error: null, lastOperation: null));
    try {
      // 1. Remove all user transactions
      await txRepo.removeAllForCurrentUser();

      // 2. Hard delete all categories and accounts for the user
      await Future.wait([
        catRepo.hardDeleteAllForCurrentUser(),
        accRepo.hardDeleteAllForCurrentUser(),
      ]);

      // 3. Re-initialize repositories (creates defaults)
      await Future.wait([
        catRepo.init(),
        accRepo.init(),
      ]);

      // 4. Refresh DataManagementCubit
      await dataCubit.refreshData();

      emit(state.copyWith(
        isLoading: false,
        lastOperation: 'All user data deleted and defaults re-initialized.',
      ));
    } catch (e, stackTrace) {
      print("Error deleting all data: $e\n$stackTrace");
      final errorMsg = 'Failed to delete all data: ${e.toString()}';
      emit(state.copyWith(
        isLoading: false,
        error: errorMsg,
        lastOperation: errorMsg,
      ));
    }
  }

  /// Helper method to check if the import file exists
  Future<bool> _checkImportFileExists() async {
    try {
      final directory = await getExternalStorageDirectory();
      final path = directory!.path;
      final filePath = '$path/transactions.json';
      return await File(filePath).exists();
    } catch (e) {
      print('Error checking import file: $e');
      return false;
    }
  }

  /// Helper method to import transactions with category and account mapping
  /// Returns both the imported transactions and count of errors occurred
  Future<_ImportResult> _importTransactionsWithRelations(
    String jsonData,
    List<Category> availableCategories,
    List<Account> availableAccounts,
  ) async {
    // Parse JSON data
    final List<dynamic> jsonList = jsonDecode(jsonData) as List;

    // Process each transaction
    final List<Transaction> transactions = [];
    int errorCount = 0;

    for (var json in jsonList) {
      if (json is Map<String, dynamic>) {
        try {
          // Skip entries that had export errors
          if (json.containsKey('exportError')) {
            errorCount++;
            print('Skipping item with export error: ${json['exportError']}');
            continue;
          }

          // --- Parse IDs ---
          // CORRECTED: Parse flat category_id, use default ID if null/missing
          int categoryId =
              json['category_id'] as int? ?? Defaults().defaultCategory.id;
          // CORRECTED: Parse flat from_account_id, use default ID if null/missing
          int fromAccountId =
              json['from_account_id'] as int? ?? Defaults().defaultAccount.id;
          // CORRECTED: Parse flat to_account_id (nullable)
          int? toAccountId = json['to_account_id'] as int?;

          // --- Parse other fields ---
          final id = json['id'] as int? ?? 0; // Use 0 for ObjectBox if missing
          // --- FIX: Parse UUID ---
          final uuid = json['uuid'] as String?; // Parse UUID (nullable)
          // --- END FIX ---
          final title = json['title'] as String? ?? 'Unnamed Transaction';
          final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
          final date = _parseDate(json['date']) ?? DateTime.now();
          final description = json['description'] as String?;
          // --- FIX: Use correct keys from toJson (created_at, updated_at, deleted_at) ---
          final createdAt = _parseDate(json['created_at']);
          final updatedAt = _parseDate(json['updated_at']);
          final deletedAt = _parseDate(json['deleted_at']);
          // --- END FIX ---
          final userId = json['user_id'] as String?; // Parse userId
          final metadata = json['metadata'] as Map<String, dynamic>?;

          // --- FIX: Use the factory constructor Transaction.createWithIds ---
          final transaction = Transaction.createWithIds(
            id: id, // Pass parsed ID (or 0)
            uuid: uuid, // Pass parsed UUID (factory handles generation if null)
            title: title,
            amount: amount,
            date: date,
            description: description,
            // Pass the IDs directly
            categoryId: categoryId,
            fromAccountId: fromAccountId,
            toAccountId: toAccountId,
            // Pass parsed dates or let factory handle defaults
            createdAt: createdAt,
            updatedAt: updatedAt,
            userId: userId, // Pass userId
            deletedAt: deletedAt, // Pass deletedAt
            metadata: metadata,
          );
          // --- END FIX ---

          transactions.add(transaction);
        } catch (e, stacktrace) {
          errorCount++;
          print('Error parsing imported transaction JSON: $e');
          print('Problematic JSON: $json');
          print('Stacktrace: $stacktrace');
          // Skip problematic transactions
        }
      }
    }

    return _ImportResult(
      transactions: transactions,
      errorCount: errorCount,
    );
  }

  /// Clears any error states
  void clearError() {
    emit(state.copyWith(error: null));
  }

  /// Clears the duplicates list
  void clearDuplicates() {
    emit(state.copyWith(duplicates: []));
  }

  /// Clear the last operation status
  void clearLastOperation() {
    emit(state.copyWith(lastOperation: null));
  }

  // Helper method to parse a date from various formats
  DateTime? _parseDate(dynamic dateValue) {
    if (dateValue == null) return null;

    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (_) {
        print("Warning: Failed to parse date string '$dateValue'");
        return null;
      }
    } else if (dateValue is int) {
      try {
        return DateTime.fromMillisecondsSinceEpoch(dateValue);
      } catch (_) {
        print("Warning: Failed to parse date from int '$dateValue'");
        return null;
      }
    }

    print("Warning: Unrecognized date format for value '$dateValue'");
    return null;
  }

  //
  // File I/O and JSON operations
  //

  /// Generates JSON data from a list of transactions
  String generateJSONData(List<Transaction> transactions) {
    try {
      // Convert transactions to list of maps using the model's toJson
      final List<Map<String, dynamic>> transactionMaps = [];

      for (var tx in transactions) {
        try {
          // --- FIX: Use the model's toJson method ---
          transactionMaps.add(tx.toJson());
          // --- END FIX ---
        } catch (e) {
          print(
              'Error exporting transaction ID ${tx.id} (UUID: ${tx.uuid}): $e');
          transactionMaps.add({
            'exportError':
                'Failed to serialize transaction ID ${tx.id} (UUID: ${tx.uuid})',
            'details': e.toString(),
          });
        }
      }

      // Convert to pretty-printed JSON string
      return const JsonEncoder.withIndent('  ').convert(transactionMaps);
    } catch (e) {
      // Handle any unexpected errors during JSON generation
      throw Exception('Failed to generate JSON: $e');
    }
  }

  /// Writes the given data to a JSON file named 'transactions.json' in the external storage directory.
  /// Returns a [Future<String>] with the path to the saved file.
  Future<String> writeToJSON(String data) async {
    final directory = await getExternalStorageDirectory();
    final path = directory!.path;
    final filePath = '$path/transactions.json';
    await File(filePath).writeAsString(data);
    return filePath;
  }

  /// Reads the 'transactions.json' file and returns its content as a string.
  /// Returns a [Future<String>] with the file's content.
  Future<String> readJSON() async {
    final directory = await getExternalStorageDirectory();
    final path = directory!.path;
    final filePath = '$path/transactions.json';

    if (!await File(filePath).exists()) {
      throw Exception('No exported transactions found.');
    }

    return await File(filePath).readAsString();
  }

  /// Converts a JSON string representation of transactions into a list of transaction objects.
  List<Transaction> fromJSONToTransactions(String data) {
    final List<dynamic> jsonList = jsonDecode(data) as List;
    return jsonList
        .map((json) => Transaction.fromJson(json as Map<String, dynamic>))
        .toList();
  }
}
