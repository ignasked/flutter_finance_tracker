import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:formz/formz.dart';
import 'package:pvp_projektas/backend/models/transaction_result.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';

import '../../../backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/formz/money_input.dart';
import 'package:pvp_projektas/front/add_transaction_screen/formz/title_input.dart';

enum ActionType { addNew, edit, delete }

class TransactionFormState extends Equatable {
  final TitleInput title;
  final MoneyInput amount;
  final String transactionType; // income / expense
  final String category; // food / travel / taxes / salary
  final DateTime date;
  final int id;

  final FormzSubmissionStatus status;

  //index in original transactionList (for editing only)
  final int? editIndex;

  //transaction that is validated and has been submitted
  final TransactionResult? submittedTransaction;
  final bool isValid; // if form is valid
  final String? errorMessage;

  //edit, add or delete transaction from original transactionList
  final ActionType actionType;

  //add transaction
  TransactionFormState(
      {this.title = const TitleInput.pure(),
      this.amount = const MoneyInput.pure(),
      this.transactionType = 'Income',
      this.category = 'Food',
      this.status = FormzSubmissionStatus.initial,
      this.isValid = false,
      DateTime? date,
      this.errorMessage,
      this.id = 0,
      this.actionType = ActionType.addNew,
      this.submittedTransaction,
      this.editIndex})
      : date = date ?? DateTime.now();

  //edit
  TransactionFormState.edit(
      {required Transaction transaction,
      this.errorMessage,
      this.submittedTransaction,
      required this.editIndex})
      : title = TitleInput.dirty(transaction.title),
        amount = MoneyInput.dirty(transaction.amount.toString()),
        transactionType = transaction.isIncome ? 'Income' : 'Expense',
        category = transaction.category,
        status = FormzSubmissionStatus.initial,
        isValid = true,
        actionType = ActionType.edit,
        id = transaction.id,
        date = transaction.date;

  TransactionFormState copyWith({
    TitleInput? title,
    MoneyInput? amount,
    String? transactionType,
    String? category,
    DateTime? date,
    FormzSubmissionStatus? status,
    bool? isValid,
    String? errorMessage,
    int? id,
    ActionType? actionType,
    TransactionResult? submittedTransaction,
    int? editIndex,
  }) {
    return TransactionFormState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      category: category ?? this.category,
      date: date ?? this.date,
      status: status ?? this.status,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      submittedTransaction: submittedTransaction ?? this.submittedTransaction,
      editIndex: editIndex ?? this.editIndex,
    );
  }

  @override
  List<Object?> get props => [
        title,
        amount,
        category,
        date,
        transactionType,
        status,
        isValid,
        errorMessage,
        id,
        actionType,
        submittedTransaction,
        editIndex,
      ];
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  // Add transaction cubit
  TransactionFormCubit() : super(TransactionFormState());

  //Edit transaction cubit
  TransactionFormCubit.edit(Transaction editTransaction, int editIndex)
      : super(TransactionFormState.edit(
          transaction: editTransaction,
          editIndex: editIndex,
        ));

  void titleChanged(String value) {
    final title = TitleInput.dirty(value);
    emit(state.copyWith(
      title: title,
      isValid: Formz.validate([title, state.amount]),
    ));
  }

  void amountChanged(String value) {
    final amount = MoneyInput.dirty(value);
    emit(state.copyWith(
      amount: amount,
      isValid: Formz.validate([state.title, amount]),
    ));
  }

  void typeChanged(String value) {
    final transactionType = value;
    emit(state.copyWith(transactionType: transactionType));
  }

  void categoryChanged(String value) {
    final cat = value;
    emit(state.copyWith(category: cat));
  }

  void dateChanged(DateTime value) {
    final date = value;
    emit(state.copyWith(date: date));
  }

  //pressed submit button (adding new or editing existing transaction)
  void submitForm() {
    if (!state.isValid) {
      emit(state.copyWith(status: FormzSubmissionStatus.failure));
      return;
    }

      emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

      try {
        final transaction = Transaction(
          id: state.id,
          title: state.title.value,
          amount: double.parse(state.amount.value),
          isIncome: state.transactionType == 'Income',
          category: state.category,
          date: state.date,
        );

        emit(state.copyWith(
            status: FormzSubmissionStatus.success,
            submittedTransaction: TransactionResult(
                transaction: transaction,
                actionType: state.actionType,
                index: state.editIndex)));
      } on Exception {
        emit(state.copyWith(status: FormzSubmissionStatus.failure));
      } catch (_) {
        emit(state.copyWith(status: FormzSubmissionStatus.failure));
      }
    }


  void deleteTransaction() {
    if (state.actionType == ActionType.edit) {
      emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

      final transaction = Transaction(
        id: state.id,
        title: state.title.value,
        amount: double.parse(state.amount.value),
        isIncome: state.transactionType == 'Income',
        category: state.category,
        date: DateTime.now(),
      );

      emit(state.copyWith(
          status: FormzSubmissionStatus.success,
          submittedTransaction: TransactionResult(
              transaction: transaction,
              actionType: ActionType.delete,
              index: state.editIndex)));
    }
  }
}
