import 'dart:convert';
import 'dart:io';

import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:money_owl/backend/models/account.dart';
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

    // Create lookup maps for categories (by id)
    final categoryIdMap = {for (var cat in availableCategories) cat.id: cat};
    // Consider adding name map as fallback if needed, but ID is primary

    // Create lookup maps for accounts (by id)
    final accountIdMap = {for (var acc in availableAccounts) acc.id: acc};
    // Consider adding name map as fallback

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

          // --- Find Category ---
          Category? category;
          // CORRECTED: Parse flat category_id
          final catId = json['category_id'] as int?;
          if (catId != null) {
            category = categoryIdMap[catId];
          }
          // Add fallback by name if necessary and if name is exported
          // category ??= categoryNameMap[ (json['category_name'] as String?)?.toLowerCase() ];
          category ??= Defaults().defaultCategory; // Use default if not found

          // --- Find From Account ---
          Account? fromAccount;
          // CORRECTED: Parse flat from_account_id
          final fromAccId = json['from_account_id'] as int?;
          if (fromAccId != null) {
            fromAccount = accountIdMap[fromAccId];
          }
          // Add fallback by name if necessary
          // fromAccount ??= accountNameMap[ (json['from_account_name'] as String?)?.toLowerCase() ];
          fromAccount ??= Defaults().defaultAccount; // Use default if not found

          // --- Find To Account ---
          Account? toAccount;
          // CORRECTED: Parse flat to_account_id
          final toAccId = json['to_account_id'] as int?;
          if (toAccId != null) {
            toAccount = accountIdMap[toAccId];
          }
          // Note: No default for toAccount, it's often null for non-transfers

          // --- Parse other fields ---
          // Use ?? 0 for ID to handle potential nulls if exporting ID 0 as null
          final id = json['id'] as int? ?? 0;
          final title = json['title'] as String? ?? 'Unnamed Transaction';
          final amount = (json['amount'] as num?)?.toDouble() ?? 0.0;
          // Use nullable _parseDate
          final date = _parseDate(json['date']) ??
              DateTime.now(); // Fallback if date parsing fails
          final description = json['description'] as String?;
          final createdAt = _parseDate(json['createdAt']); // Nullable
          final updatedAt = _parseDate(json['updatedAt']); // Nullable
          final userId = json['user_id'] as String?; // Parse userId
          final deletedAt =
              _parseDate(json['deleted_at']); // Parse deletedAt (nullable)
          final metadata = json['metadata'] as Map<String, dynamic>?;

          // Create transaction using the constructor, passing found objects
          final transaction = Transaction(
            id: id,
            title: title,
            amount: amount,
            date: date,
            description: description,
            category: category, // Pass the Category object
            fromAccount: fromAccount, // Pass the Account object
            toAccount: toAccount, // Pass the Account object (can be null)
            // Pass IDs as well, constructor prioritizes objects but good practice
            categoryId: category?.id,
            fromAccountId: fromAccount?.id,
            toAccountId: toAccount?.id,
            // Use parsed dates or fallback to now() if parsing failed
            createdAt: createdAt ?? DateTime.now(),
            updatedAt: updatedAt ?? DateTime.now(),
            userId: userId, // Pass userId
            deletedAt: deletedAt, // Pass deletedAt
            metadata: metadata,
          );

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

  /// Process a receipt JSON data to extract transactions
  Future<Map<String, dynamic>> processReceiptData(
      Map<String, dynamic> json, List<Category> availableCategories) async {
    try {
      emit(state.copyWith(isLoading: true));

      // Extract basic receipt data
      final transactionName = json['transactionName'] is String
          ? json['transactionName'] as String
          : 'Unknown Store';

      final date = _parseDate(json['date']) ?? DateTime.now();

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
                // Let the BulkAddTransactionsScreen handle account assignment
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

      // Final structured receipt data
      final result = {
        'transactionName': transactionName,
        'date': date,
        'totalAmountPaid': totalAmount,
        'transactions': transactions,
      };

      emit(state.copyWith(
        isLoading: false,
        lastOperation: 'Processed receipt with ${transactions.length} items',
      ));

      return result;
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
        lastOperation: 'Receipt processing failed',
      ));

      // Return empty receipt data structure with the error
      return {
        'transactionName': 'Error',
        'date': DateTime.now(),
        'totalAmountPaid': 0.0,
        'transactions': <Transaction>[],
        'error': e.toString(),
      };
    }
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
      // Convert transactions to list of maps
      final List<Map<String, dynamic>> transactionMaps = [];

      // Process each transaction
      for (var tx in transactions) {
        try {
          // Use targetId directly - safer for potentially detached objects
          final categoryId = tx.category.targetId;
          final fromAccountId = tx.fromAccount.targetId;
          final toAccountId = tx.toAccount.targetId; // Add toAccount export

          // Create a transaction JSON object
          final map = {
            'id': tx.id,
            'title': tx.title,
            'amount': tx.amount,
            'date': tx.date.toIso8601String(),
            'description': tx.description,
            'createdAt': tx.createdAt.toIso8601String(),
            'updatedAt': tx.updatedAt.toIso8601String(),
            // Export only the IDs
            'category_id': categoryId == 0 ? null : categoryId,
            'from_account_id': fromAccountId == 0 ? null : fromAccountId,
            'to_account_id':
                toAccountId == 0 ? null : toAccountId, // Add to_account_id
            'user_id': tx.userId, // Ensure userId is exported
            'deleted_at': tx.deletedAt?.toIso8601String(), // Export deleted_at
          };

          // Add metadata if available
          if (tx.metadata != null) {
            map['metadata'] = tx.metadata;
          }

          transactionMaps.add(map);
        } catch (e) {
          // If individual transaction processing fails (less likely now)
          print('Error processing transaction ${tx.id} for export: $e');
          transactionMaps.add({
            'exportError': 'Failed to process transaction ${tx.id}: $e',
            'id': tx.id, // Include basic info for identification
            'title': tx.title,
            'amount': tx.amount,
            'date': tx.date.toIso8601String(),
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
