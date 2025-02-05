import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';
import 'package:formz/formz.dart';
import 'package:pvp_projektas/front/home_screen/cubit/transaction_cubit.dart';

import '../../../backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/formz/money_input.dart';
import 'package:pvp_projektas/front/add_transaction_screen/formz/title_input.dart';

enum TransactionFormType { addNew, edit }

class TransactionFormState extends Equatable {
  final TitleInput title;
  final MoneyInput amount;
  final String transactionType; // income / expense
  final String category; // food / travel / taxes / salary
  final int id;

  final FormzSubmissionStatus status;
  final bool isValid; // if form is valid
  final String? errorMessage;

  //final Transaction? initialTransaction; // for editing
  final TransactionFormType formType;

  //add transaction
  TransactionFormState({
    this.title = const TitleInput.pure(),
    this.amount = const MoneyInput.pure(),
    this.transactionType = 'Income',
    this.category = 'Food',
    this.status = FormzSubmissionStatus.initial,
    this.isValid = false,
    this.errorMessage,
    this.id = 0,
    //this.initialTransaction,
    this.formType = TransactionFormType.addNew,
  });

  //edit
  TransactionFormState.edit(
      {required Transaction transaction, this.errorMessage})
      : title = TitleInput.dirty(transaction.title),
        amount = MoneyInput.dirty(transaction.amount.toString()),
        transactionType = transaction.isIncome ? 'Income' : 'Expense',
        category = transaction.category,
        status = FormzSubmissionStatus.initial,
        isValid = true,
        formType = TransactionFormType.edit,
        id = transaction.id;

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
    TransactionFormType? formType,
  }) {
    return TransactionFormState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      transactionType: transactionType ?? this.transactionType,
      category: category ?? this.category,
      status: status ?? this.status,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
      id: id ?? this.id,
      formType: formType ?? this.formType,
    );
  }


  @override
  List<Object?> get props => [title, amount, category, transactionType, status, isValid, errorMessage, id, formType];
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  //TODO: remove cubit
  final TransactionCubit transactionsCubit;
  int? index; // transaction index in transactionList

  // Add transaction cubit
  TransactionFormCubit(this.transactionsCubit) : super(TransactionFormState());

  //Edit transaction cubit
  TransactionFormCubit.edit(
      this.transactionsCubit, Transaction editTransaction, this.index)
      : super(TransactionFormState.edit(
          transaction: editTransaction,
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
    emit(state.copyWith(date: value));
  }

  //pressed submit button (adding new or editing existing transaction)
  void submitForm(BuildContext context) {
    if (!state.isValid) return;
    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));
    try {
      final transaction = Transaction(
        id: state.id,
        title: state.title.value,
        amount: double.parse(state.amount.value),
        isIncome: state.transactionType == 'Income',
        category: state.category,
        date: DateTime.now(),
      );
      if (state.formType == TransactionFormType.addNew) {
        addTransaction(transaction);
      } else if (state.formType == TransactionFormType.edit) {
        saveTransaction(transaction, context);
      }
      emit(state.copyWith(status: FormzSubmissionStatus.success));
      //close this window
      //Navigator.pop(context, transaction);
    } on Exception {
      emit(state.copyWith(status: FormzSubmissionStatus.failure));
    } catch (_) {
      emit(state.copyWith(status: FormzSubmissionStatus.failure));
    }
  }

  //save edited transaction
  void saveTransaction(Transaction transaction, BuildContext context) {
    transactionsCubit.updateTransaction(transaction, index!);
  }

  //add new transaction
  void addTransaction(Transaction transaction) {
    transactionsCubit.addTransaction(transaction);
  }

  void deleteTransaction(int index, BuildContext context) {
    transactionsCubit.deleteTransaction(index);
    //TODO: ask if its a good practice to use Navigator.pop(context) in cubit
    //Navigator.pop(context);
  }
}
