part of 'importer_cubit.dart';

/// State for the [ImporterCubit]
class ImporterState extends Equatable {
  final List<Transaction> duplicates;
  final bool isLoading;
  final String? error;
  final String? exportPath;
  final String? lastOperation;

  const ImporterState({
    this.duplicates = const [],
    this.isLoading = false,
    this.error,
    this.exportPath,
    this.lastOperation,
  });

  @override
  List<Object?> get props =>
      [duplicates, isLoading, error, exportPath, lastOperation];

  ImporterState copyWith({
    List<Transaction>? duplicates,
    bool? isLoading,
    String? error,
    String? exportPath,
    String? lastOperation,
  }) {
    return ImporterState(
      duplicates: duplicates ?? this.duplicates,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
      exportPath: exportPath ?? this.exportPath,
      lastOperation: lastOperation ?? this.lastOperation,
    );
  }
}
