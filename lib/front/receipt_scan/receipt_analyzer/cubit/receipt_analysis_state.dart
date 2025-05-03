part of 'receipt_analysis_cubit.dart';

abstract class ReceiptAnalysisState extends Equatable {
  const ReceiptAnalysisState();

  @override
  List<Object?> get props => [];
}

class ReceiptAnalysisInitial extends ReceiptAnalysisState {}

class ReceiptAnalysisLoading extends ReceiptAnalysisState {}

class ReceiptAnalysisSuccess extends ReceiptAnalysisState {
  final Map<String, dynamic> receiptData;

  const ReceiptAnalysisSuccess(this.receiptData);

  @override
  List<Object?> get props => [receiptData];
}

class ReceiptAnalysisError extends ReceiptAnalysisState {
  final String message;

  const ReceiptAnalysisError(this.message);

  @override
  List<Object?> get props => [message];
}

class ReceiptAnalysisImageSelected extends ReceiptAnalysisState {
  final File imageFile;

  const ReceiptAnalysisImageSelected(this.imageFile);

  @override
  List<Object?> get props => [imageFile];
}
