import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/models/transaction_result.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/backend/utils/enums.dart';

import '../../../backend/models/transaction.dart';
import 'package:money_owl/front/transaction_form_screen/formz/money_input.dart';
import 'package:money_owl/front/transaction_form_screen/formz/title_input.dart';

enum ActionType { addNew, edit, delete }

class TransactionFormState extends Equatable {
  final TitleInput title;
  final MoneyInput amount;
  final Category? category; // Selected category
  final Account? account; // Selected account
  final DateTime date;
  final int id;
  final TransactionType selectedType; // Default transaction type

  final FormzSubmissionStatus status;

  // Index in original transactionList (for editing only)
  // final int? editIndex;

  // Transaction that is validated and has been submitted
  final TransactionResult? submittedTransaction;
  final bool isValid; // If form is valid
  final String? errorMessage;

  // Edit, add, or delete transaction from original transactionList
  final ActionType actionType;

  // Add transaction
  TransactionFormState({
    this.title = const TitleInput.pure(),
    this.amount = const MoneyInput.pure(),
    Category? category,
    Account? account, // Initialize account
    this.status = FormzSubmissionStatus.initial,
    this.isValid = false,
    DateTime? date,
    this.errorMessage,
    this.id = 0,
    this.actionType = ActionType.addNew,
    this.submittedTransaction,
    // this.editIndex,
    this.selectedType = TransactionType.expense, // Default to expense
  })  : date = date ?? DateTime.now(),
        category = category ?? Defaults().defaultCategory,
        account = account ?? Defaults().defaultAccount; // Initialize account

  // Edit transaction
  TransactionFormState.edit({
    required Transaction transaction,
    this.errorMessage,
    this.submittedTransaction,
    // required this.editIndex,
  })  : title = TitleInput.dirty(transaction.title),
        amount = MoneyInput.dirty(transaction.amount.toString()),
        category = transaction.category.target, // Use the target Category
        account = transaction.fromAccount.target, // Use the target Account
        status = FormzSubmissionStatus.initial,
        isValid = true,
        actionType = ActionType.edit,
        id = transaction.id,
        date = transaction.date,
        selectedType =
            transaction.category.target!.type; // Use the transaction type

  TransactionFormState copyWith({
    TitleInput? title,
    MoneyInput? amount,
    String? transactionType,
    Category? category,
    Account? account, // Add account to copyWith
    DateTime? date,
    FormzSubmissionStatus? status,
    bool? isValid,
    String? errorMessage,
    int? id,
    ActionType? actionType,
    TransactionResult? submittedTransaction,
    int? editIndex,
    TransactionType? selectedType, // Add selectedType to copyWith
  }) {
    if (category != null) {
      selectedType = category.type; // Update selectedType based on category
    }
    return TransactionFormState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      account: account ?? this.account, // Copy account
      date: date ?? this.date,
      status: status ?? this.status,
      isValid: isValid ?? this.isValid,
      errorMessage: errorMessage ?? this.errorMessage,
      id: id ?? this.id,
      actionType: actionType ?? this.actionType,
      submittedTransaction: submittedTransaction ?? this.submittedTransaction,
      // editIndex: editIndex ?? this.editIndex,
      selectedType: selectedType ?? this.selectedType, // Copy selectedType
    );
  }

  @override
  List<Object?> get props => [
        title,
        amount,
        category,
        account, // Include account in props
        date,
        status,
        isValid,
        errorMessage,
        id,
        actionType,
        submittedTransaction,
        // editIndex,
        selectedType, // Include selectedType in props
      ];
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  // Add transaction cubit
  TransactionFormCubit() : super(TransactionFormState());

  // Edit transaction cubit
  TransactionFormCubit.edit(Transaction editTransaction)
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

  void typeChanged(TransactionType newType) {
    emit(state.copyWith(selectedType: newType));
  }

  void categoryChanged(Category category) {
    emit(state.copyWith(category: category));
  }

  void dateChanged(DateTime value) {
    final date = value;
    emit(state.copyWith(date: date));
  }

  void accountChanged(Account value) {
    final account = value;
    emit(state.copyWith(account: account));
  }

  // Pressed submit button (adding new or editing existing transaction)
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
        category: state.category, // Use the selected Category
        fromAccount: state.account, // Use the selected Account
        date: state.date,
      );

      emit(state.copyWith(
          status: FormzSubmissionStatus.success,
          submittedTransaction: TransactionResult(
            transaction: transaction,
            actionType: state.actionType,
          ))); //index: state.editIndex
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
        category: state.category, // Use the selected Category
        fromAccount: state.account, // Use the selected Account
        date: DateTime.now(),
      );

      emit(state.copyWith(
          status: FormzSubmissionStatus.success,
          actionType: ActionType.delete,
          submittedTransaction: TransactionResult(
            transaction: transaction,
            actionType: ActionType.delete,
          ))); //index: state.editIndex
    }
  }
}
