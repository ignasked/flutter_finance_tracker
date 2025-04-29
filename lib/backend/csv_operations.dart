import 'package:path_provider/path_provider.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'dart:io';

String generateCSVData(List<Transaction> transactions) {
  String csvData = "";
  csvData += "${Transaction.toCSVHeader()}\n";
  for (int i = 0; i < transactions.length; i++) {
    csvData += "${transactions[i].toCSV()}\n";
  }
  return csvData;
}

/// Writes the given data to a CSV file named 'transactions.csv' in the external storage directory.
/// Returns a [Future<void>] indicating the completion of the write operation.
Future<void> writeToCSV(String data) async {
  // Map<Permission, PermissionStatus> statuses = await [
  //   Permission.storage,
  // ].request();
  final directory = await getExternalStorageDirectory();
  final path = directory!.path;
  File('$path/transactions.csv').writeAsString(data);
  print('$path/transactions.csv');
}

/// Reads the 'transactions.csv' file and returns its content as a string.
/// Returns a [Future<String>] with the file's content.
Future<String> readCSV() async {
  final directory = await getExternalStorageDirectory();
  final path = directory!.path;
  return File('$path/transactions.csv').readAsString();
}

// Converts a string representation of transactions (CSV) into a list of transaction objects.
List<Transaction> fromStringToTransactions(String data) {
  List<String> lines = data.split('\n');
  List<Transaction> transactions = [];
  for (int i = 1; i < lines.length; i++) {
    if (lines[i].trim().isNotEmpty) {
      transactions.add(Transaction.fromCSV(lines[i]));
    }
  }
  return transactions;
}
