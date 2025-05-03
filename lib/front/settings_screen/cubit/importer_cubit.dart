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

    // Create lookup maps for categories (by id and name)
    final categoryIdMap = {for (var cat in availableCategories) cat.id: cat};
    final categoryNameMap = {
      for (var cat in availableCategories) cat.title.toLowerCase(): cat
    };

    // Create lookup maps for accounts (by id and name)
    final accountIdMap = {for (var acc in availableAccounts) acc.id: acc};
    final accountNameMap = {
      for (var acc in availableAccounts) acc.name.toLowerCase(): acc
    };

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

          // Extract category from JSON
          Category? category;

          // First try to get category by ID
          if (json['category'] != null &&
              json['category'] is Map &&
              json['category']['id'] != null) {
            final catId = json['category']['id'] as int;
            category = categoryIdMap[catId];
          }

          // If no category found by ID, try by name
          if (category == null &&
              json['category'] != null &&
              json['category'] is Map &&
              json['category']['title'] != null) {
            final catName = (json['category']['title'] as String).toLowerCase();
            category = categoryNameMap[catName];
          }

          // If still no category, use default
          category ??= Defaults().defaultCategory;

          // Extract account from JSON
          Account? account;

          // First try to get account by ID
          if (json['fromAccount'] != null &&
              json['fromAccount'] is Map &&
              json['fromAccount']['id'] != null) {
            final accId = json['fromAccount']['id'] as int;
            account = accountIdMap[accId];
          }

          // If no account found by ID, try by name
          if (account == null &&
              json['fromAccount'] != null &&
              json['fromAccount'] is Map &&
              json['fromAccount']['name'] != null) {
            final accName =
                (json['fromAccount']['name'] as String).toLowerCase();
            account = accountNameMap[accName];
          }

          // If still no account, use default
          account ??= Defaults().defaultAccount;

          // Create transaction with properly linked relations
          final transaction = Transaction(
            id: json['id'] as int? ?? 0,
            title: json['title'] as String? ?? 'Unnamed Transaction',
            amount: (json['amount'] as num?)?.toDouble() ?? 0.0,
            date: _parseDate(json['date']),
            description: json['description'] as String?,
            category: category,
            fromAccount: account,
            createdAt: _parseDate(json['createdAt']),
            updatedAt: _parseDate(json['updatedAt']),
            metadata: json['metadata'] as Map<String, dynamic>?,
          );

          transactions.add(transaction);
        } catch (e) {
          errorCount++;
          print('Error parsing transaction: $e');
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
  DateTime _parseDate(dynamic dateValue) {
    if (dateValue == null) return DateTime.now();

    if (dateValue is DateTime) {
      return dateValue;
    } else if (dateValue is String) {
      try {
        return DateTime.parse(dateValue);
      } catch (_) {
        try {
          // Try different date formats if standard parsing fails
          final formats = [
            'yyyy-MM-dd',
            'yyyy/MM/dd',
            'dd-MM-yyyy',
            'dd/MM/yyyy',
            'MM/dd/yyyy'
          ];

          for (final format in formats) {
            try {
              // This is a simplified approach; in a real app, you might use a proper
              // date formatting library like intl for this
              if (format == 'yyyy-MM-dd' && dateValue.contains('-')) {
                final parts = dateValue.split('-');
                if (parts.length == 3) {
                  return DateTime(int.parse(parts[0]), int.parse(parts[1]),
                      int.parse(parts[2]));
                }
              } else if (format.contains('/') && dateValue.contains('/')) {
                final parts = dateValue.split('/');
                if (parts.length == 3) {
                  // Handle different date formats
                  if (format.startsWith('dd')) {
                    return DateTime(int.parse(parts[2]), int.parse(parts[1]),
                        int.parse(parts[0]));
                  } else if (format.startsWith('MM')) {
                    return DateTime(int.parse(parts[2]), int.parse(parts[0]),
                        int.parse(parts[1]));
                  } else {
                    return DateTime(int.parse(parts[0]), int.parse(parts[1]),
                        int.parse(parts[2]));
                  }
                }
              }
            } catch (_) {
              // Continue to next format
            }
          }
        } catch (_) {}

        // If all parsing attempts fail, return current date
        return DateTime.now();
      }
    } else if (dateValue is int) {
      // Assume milliseconds since epoch
      return DateTime.fromMillisecondsSinceEpoch(dateValue);
    }

    return DateTime.now();
  }

  //
  // File I/O and JSON operations
  //

  /// Generates JSON data from a list of transactions
  String generateJSONData(List<Transaction> transactions) {
    try {
      // Convert transactions to list of maps
      final List<Map<String, dynamic>> transactionMaps = [];

      // Process each transaction with error handling
      for (var tx in transactions) {
        try {
          // Check if category relation is initialized
          final category = tx.category.target;
          final fromAccount = tx.fromAccount.target;

          // Create a transaction JSON object with proper error handling for relations
          final map = {
            'id': tx.id,
            'title': tx.title,
            'amount': tx.amount,
            'date': tx.date.toIso8601String(),
            'description': tx.description,
            'createdAt': tx.createdAt.toIso8601String(),
            'updatedAt': tx.updatedAt.toIso8601String(),
            // Safely add category with null check
            'category': category != null
                ? {
                    'id': category.id,
                    'title': category.title,
                    'type': category.type.toString().split('.').last,
                  }
                : null,
            // Safely add fromAccount with null check
            'fromAccount': fromAccount != null
                ? {
                    'id': fromAccount.id,
                    'name': fromAccount.name,
                    'currency': fromAccount.currency,
                  }
                : null,
          };

          // Add metadata if available
          if (tx.metadata != null) {
            map['metadata'] = tx.metadata;
          }

          transactionMaps.add(map);
        } catch (e) {
          // If individual transaction processing fails, add an error entry
          print('Error processing transaction ${tx.id}: $e');
          transactionMaps.add({
            'exportError': 'Failed to process transaction ${tx.id}: $e',
            'id': tx.id,
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
