import 'package:bloc/bloc.dart';
import 'package:flutter/material.dart';
import 'package:pvp_projektas/models/Transaction.dart';

enum EditorType { add_new, edit }

class TransactionFormState {
  final int? id; // `null` for new transactions, set for editing
  final String title;
  final String amount;
  final String type;
  final String category;
  final DateTime date;
  final EditorType editorType;

  TransactionFormState({
    this.id,
    required this.title,
    required this.amount,
    required this.type,
    required this.category,
    required this.date,
    required this.editorType,
  });

  TransactionFormState copyWith({
    int? id,
    String? title,
    String? amount,
    String? type,
    String? category,
    DateTime? date,
    EditorType? editorType,
  }) {
    return TransactionFormState(
      id: id ?? this.id,
      title: title ?? this.title,
      amount: amount ?? this.amount,
      type: type ?? this.type,
      category: category ?? this.category,
      date: date ?? this.date,
      editorType: editorType ?? this.editorType,
    );
  }
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit(Transaction? transaction)
      : super(
    TransactionFormState(
      id: transaction?.id,
      title: transaction?.title ?? '',
      amount: transaction?.amount.toString() ?? '',
      type: transaction?.isIncome ?? true ? 'Income' : 'Expense',
      category: transaction?.category ?? 'Food',
      date: transaction?.date ?? DateTime.now(),
      editorType: transaction == null ? EditorType.add_new : EditorType.edit,
    ),
  );

  void updateTitle(String title) {
    emit(state.copyWith(title: title));
  }

  void updateAmount(String amount) {
    emit(state.copyWith(amount: amount));
  }

  void updateType(String type) {
    emit(state.copyWith(type: type));
  }

  void updateCategory(String category) {
    emit(state.copyWith(category: category));
  }

  void updateDate(DateTime date) {
    emit(state.copyWith(date: date));
  }

  void submitForm() {
    if (_isValidForm()) {
      final double parsedAmount = double.tryParse(state.amount) ?? 0.0;

      final transaction = Transaction(
        id: state.id ?? 0, // Use existing ID for editing, or 0 for a new transaction
        title: state.title,
        amount: parsedAmount,
        isIncome: state.type == 'Income',
        category: state.category,
        date: state.date,
      );

      // Handle submission (e.g., send to ObjectBox or emit to parent Cubit)
      print('Submitted Transaction: $transaction');
    } else {
      emit(TransactionFormState(
        id: state.id,
        title: state.title,
        amount: state.amount,
        type: state.type,
        category: state.category,
        date: state.date,
        editorType: state.editorType,
      ));
    }
  }

  bool _isValidForm() {
    if (state.title.isEmpty || double.tryParse(state.amount) == null) {
      return false;
    }
    return true;
  }
}
