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
  final DateTime date;

  final FormzSubmissionStatus status;
  final bool isValid; // if form is valid
  final String? errorMessage;
  final Transaction? initialTransaction; // for editing
  final TransactionFormType formType;

  TransactionFormState({
    this.title = const TitleInput.pure(),
    this.amount = const MoneyInput.pure(),
    this.transactionType = 'Income',
    this.category = 'Food',
    DateTime? selectedDate,
    this.status = FormzSubmissionStatus.initial,
    this.isValid = false,
    this.errorMessage,
    this.initialTransaction,
    this.formType = TransactionFormType.addNew,
  }): date = selectedDate ?? DateTime.now();

  TransactionFormState copyWith({
    TitleInput? title,
    MoneyInput? amount,
    String? selectedType,
    String? selectedCategory,
    DateTime? selectedDate,
    FormzSubmissionStatus? status,
    bool? isValid,
    String? errorMessage,
    Transaction? initialTransaction,
    TransactionFormType? formType,
  }){
    return TransactionFormState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      transactionType: selectedType ?? this.transactionType,
      category: selectedCategory ?? this.category,
      selectedDate: selectedDate ?? this.date,
      status: status ?? this.status,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
      initialTransaction: initialTransaction ?? this.initialTransaction,
      formType: initialTransaction != null ? TransactionFormType.edit : formType ?? this.formType,
    );
  }

  @override
  List<Object?> get props => [title, amount, status, isValid, errorMessage, initialTransaction];
  }

class TransactionFormCubit extends Cubit<TransactionFormState> {
  //final TransactionRepository transRepository;
  final TransactionCubit transactionsCubit;
  final int? index; // transaction index in transactionList


  // Initialize with an empty or default transaction
  TransactionFormCubit(this.transactionsCubit, Transaction? initialTransaction, this.index)
      : super(TransactionFormState(
    title: initialTransaction != null ? TitleInput.dirty(initialTransaction.title) : const TitleInput.pure(),
    amount: initialTransaction != null ? MoneyInput.dirty(initialTransaction.amount.toString()) : const MoneyInput.pure(),
    transactionType: initialTransaction?.isIncome == true ? 'Income' : 'Expense',
    category: initialTransaction?.category ?? 'Food',
    selectedDate: initialTransaction?.date ?? DateTime.now(),
    formType: initialTransaction != null ? TransactionFormType.edit : TransactionFormType.addNew,
    initialTransaction: initialTransaction,
    isValid: initialTransaction != null,));

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
    emit(state.copyWith(selectedType: value));
  }

  void categoryChanged(String value) {
    emit(state.copyWith(selectedCategory: value));
  }

  void dateChanged(DateTime value) {
    emit(state.copyWith(selectedDate: value));
  }

  void submitForm(BuildContext context){
    if(!state.isValid) return;
    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));
    try {
      final transaction = Transaction(
        id: state.initialTransaction?.id ?? 0,
        title: state.title.value,
        amount: double.parse(state.amount.value),
        isIncome: state.transactionType == 'Income',
        category: state.category,
        date: state.date,
      );
      if(state.formType == TransactionFormType.addNew) {
        transactionsCubit.addTransaction(transaction);
      }
      else{
        transactionsCubit.updateTransaction(transaction, index!);
      }
      //transRepository.addTransaction(transaction);


      emit(state.copyWith(status: FormzSubmissionStatus.success));
      Navigator.pop(context, transaction);
    } on Exception {
      emit(state.copyWith(status: FormzSubmissionStatus.failure));
    } catch (_){
      emit(state.copyWith(status: FormzSubmissionStatus.failure));
    }
  }
}
