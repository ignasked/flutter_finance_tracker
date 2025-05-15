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
      // --- HARD DELETE FROM SUPABASE AND LOCAL ---
      await txRepo.hardDeleteAllForCurrentUser();
      await Future.wait([
        catRepo.hardDeleteAllForCurrentUser(),
        accRepo.hardDeleteAllForCurrentUser(),
      ]);

      // 2. Initialize default categories and accounts (must be done before init)
      await catRepo.initializeDefaultCategories();
      await accRepo.initializeDefaultAccounts();

      // 3. Re-initialize repositories (if needed for any cache/state)
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

    // Build lookup maps for category/account by title/name (case-insensitive)
    final Map<String, int> categoryTitleToId = {
      for (var cat in availableCategories)
        cat.title.trim().toLowerCase(): cat.id
    };
    final Map<String, int> accountNameToId = {
      for (var acc in availableAccounts) acc.name.trim().toLowerCase(): acc.id
    };
    // Build maps from default ID to title/name
    final Map<int, String> defaultCategoryIdToTitle = {
      for (var cat in Defaults().defaultCategoriesData)
        cat.id: cat.title.trim().toLowerCase()
    };
    final Map<int, String> defaultAccountIdToName = {
      for (var acc in Defaults().defaultAccountsData)
        acc.id: acc.name.trim().toLowerCase()
    };

    // --- Get current default IDs for fallback ---
    final int currentDefaultCategoryId = Defaults().defaultCategory.id;
    final int currentDefaultAccountId = Defaults().defaultAccount.id;

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

          // --- Map category_id to current DB ---
          int? categoryId = json['category_id'] as int?;
          // 1. Try to find by ID in availableCategories
          if (categoryId != null &&
              availableCategories.any((c) => c.id == categoryId)) {
            // Use as-is
          } else {
            // 2. Try to find by title (for defaults or custom)
            String? categoryTitle;
            if (categoryId != null &&
                defaultCategoryIdToTitle.containsKey(categoryId)) {
              categoryTitle = defaultCategoryIdToTitle[categoryId];
            } else if (json['category_title'] != null) {
              categoryTitle =
                  (json['category_title'] as String).trim().toLowerCase();
            } else if (json['category'] != null &&
                json['category'] is Map &&
                (json['category']['title'] != null)) {
              categoryTitle =
                  (json['category']['title'] as String).trim().toLowerCase();
            }
            if (categoryTitle != null &&
                categoryTitleToId.containsKey(categoryTitle)) {
              categoryId = categoryTitleToId[categoryTitle];
            } else {
              categoryId = currentDefaultCategoryId;
            }
          }

          // --- Map from_account_id to current DB ---
          int? fromAccountId = json['from_account_id'] as int?;
          if (fromAccountId != null &&
              availableAccounts.any((a) => a.id == fromAccountId)) {
            // Use as-is
          } else {
            String? accountName;
            if (fromAccountId != null &&
                defaultAccountIdToName.containsKey(fromAccountId)) {
              accountName = defaultAccountIdToName[fromAccountId];
            } else if (json['from_account_name'] != null) {
              accountName =
                  (json['from_account_name'] as String).trim().toLowerCase();
            } else if (json['from_account'] != null &&
                json['from_account'] is Map &&
                (json['from_account']['name'] != null)) {
              accountName =
                  (json['from_account']['name'] as String).trim().toLowerCase();
            }
            if (accountName != null &&
                accountNameToId.containsKey(accountName)) {
              fromAccountId = accountNameToId[accountName];
            } else {
              fromAccountId = currentDefaultAccountId;
            }
          }

          // --- Map to_account_id to current DB ---
          int? toAccountId = json['to_account_id'] as int?;
          if (toAccountId != null &&
              availableAccounts.any((a) => a.id == toAccountId)) {
            // Use as-is
          } else if (toAccountId != null) {
            String? accountName;
            if (defaultAccountIdToName.containsKey(toAccountId)) {
              accountName = defaultAccountIdToName[toAccountId];
            } else if (json['to_account_name'] != null) {
              accountName =
                  (json['to_account_name'] as String).trim().toLowerCase();
            } else if (json['to_account'] != null &&
                json['to_account'] is Map &&
                (json['to_account']['name'] != null)) {
              accountName =
                  (json['to_account']['name'] as String).trim().toLowerCase();
            }
            if (accountName != null &&
                accountNameToId.containsKey(accountName)) {
              toAccountId = accountNameToId[accountName];
            } else {
              toAccountId = currentDefaultAccountId;
            }
          }

          // --- Ensure IDs are non-null for Transaction.createWithIds ---
          final int finalCategoryId = categoryId ?? currentDefaultCategoryId;
          final int finalFromAccountId =
              fromAccountId ?? currentDefaultAccountId;
          final int? finalToAccountId = toAccountId ??
              (toAccountId == null ? null : currentDefaultAccountId);

          // --- Parse other fields ---
          final id = json['id'] as int? ?? 0; // Use 0 for ObjectBox if missing
          final uuid = json['uuid'] as String?;
          final title = json['title'] as String? ?? 'Unnamed Transaction';
          final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
          final date = _parseDate(json['date']) ?? DateTime.now();
          final description = json['description'] as String?;
          final createdAt = _parseDate(json['created_at']);
          final updatedAt = _parseDate(json['updated_at']);
          final deletedAt = _parseDate(json['deleted_at']);
          final userId = json['user_id'] as String?;
          final metadata = json['metadata'] as Map<String, dynamic>?;

          final transaction = Transaction.createWithIds(
            id: id,
            uuid: uuid,
            title: title,
            amount: amount,
            date: date,
            description: description,
            categoryId: finalCategoryId,
            fromAccountId: finalFromAccountId,
            toAccountId: finalToAccountId,
            createdAt: createdAt,
            updatedAt: updatedAt,
            userId: userId,
            deletedAt: deletedAt,
            metadata: metadata,
          );

          transactions.add(transaction);
        } catch (e, stacktrace) {
          errorCount++;
          print('Error parsing imported transaction JSON: $e');
          print('Problematic JSON: $json');
          print('Stacktrace: $stacktrace');
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
          transactionMaps.add(tx.toExportJson());
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
