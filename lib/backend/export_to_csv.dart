import 'package:path_provider/path_provider.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'dart:io';

// void exportToCSV1(List<Transaction> transactions) {
//   List<String> header = ['ID','Title','Amount','IsIncome','Category','Date'];
//   List<String> data = [transactions[0].id.toString(), transactions[0].title, transactions[0].amount.toString(), transactions[0].isIncome.toString(), transactions[0].category, transactions[0].date.toString()];
// }

String generateCSVData(List<Transaction> transactions) {
  String csvData = "";
  csvData += "${Transaction.toCSVHeader()}\n";
  for (int i = 0; i < transactions.length; i++) {
    csvData += "${transactions[i].toCSV()}\n";
  }
  return csvData;
}

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
