part of 'receipt_analysis_cubit.dart';

abstract class ReceiptAnalysisState {}

class ReceiptAnalysisInitial extends ReceiptAnalysisState {}

class ReceiptAnalysisLoading extends ReceiptAnalysisState {}

class ReceiptAnalysisSuccess extends ReceiptAnalysisState {
  final Map<String, dynamic> receiptData;

  ReceiptAnalysisSuccess(this.receiptData);
}

class ReceiptAnalysisError extends ReceiptAnalysisState {
  final String message;

  ReceiptAnalysisError(this.message);
}

class ReceiptAnalysisImageSelected extends ReceiptAnalysisState {
  final File imageFile;

  ReceiptAnalysisImageSelected(this.imageFile);
}
