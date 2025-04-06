import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/backend/export_to_csv.dart';

class CsvState extends Equatable {
  final List<Transaction> duplicates;
  final bool isLoading;
  final String? error;

  const CsvState({
    this.duplicates = const [],
    this.isLoading = false,
    this.error,
  });

  @override
  List<Object?> get props => [duplicates, isLoading, error];

  CsvState copyWith({
    List<Transaction>? duplicates,
    bool? isLoading,
    String? error,
  }) {
    return CsvState(
      duplicates: duplicates ?? this.duplicates,
      isLoading: isLoading ?? this.isLoading,
      error: error ?? this.error,
    );
  }
}

class CsvCubit extends Cubit<CsvState> {
  CsvCubit() : super(const CsvState());

  Future<void> exportTransactions(List<Transaction> transactions) async {
    try {
      emit(state.copyWith(isLoading: true));
      final csvData = generateCSVData(transactions);
      await writeToCSV(csvData);
      emit(state.copyWith(isLoading: false));
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
    }
  }

  Future<List<Transaction>?> importTransactions(
    List<Transaction> existingTransactions,
    bool includeDuplicates,
  ) async {
    try {
      emit(state.copyWith(isLoading: true));
      final data = await readCSV();
      final newTransactions = fromStringToTransactions(data);

      // Find duplicates
      final duplicates = newTransactions
          .where((newTx) => existingTransactions.contains(newTx))
          .toList();

      if (duplicates.isNotEmpty && !includeDuplicates) {
        emit(state.copyWith(
          isLoading: false,
          duplicates: duplicates,
        ));
        return null;
      }

      emit(state.copyWith(isLoading: false, duplicates: []));
      return newTransactions;
    } catch (e) {
      emit(state.copyWith(isLoading: false, error: e.toString()));
      return null;
    }
  }
}
