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
  final Category? category; // Keep Category object for dropdown display
  final Account? account; // Keep Account object for dropdown display
  final DateTime date;
  final int id;
  final TransactionType selectedType; // Default transaction type

  final FormzSubmissionStatus status;

  final TransactionResult? submittedTransaction;
  final bool isValid; // If form is valid
  final String? errorMessage;

  final ActionType actionType;

  TransactionFormState({
    this.title = const TitleInput.pure(),
    this.amount = const MoneyInput.pure(),
    DateTime? date, // Accept optional date
    this.category,
    this.account,
    this.selectedType = TransactionType.expense, // Default type
    this.status = FormzSubmissionStatus.initial,
    this.submittedTransaction,
    this.isValid = false, // Default to false for new form
    this.errorMessage,
    this.actionType = ActionType.addNew,
    this.id = 0, // Default ID for new transaction
  }) : date = date ?? DateTime.now(); // Initialize this.date

  TransactionFormState.edit({
    required Transaction transaction,
    this.errorMessage,
    this.submittedTransaction,
  })  : title = TitleInput.dirty(transaction.title),
        amount = MoneyInput.dirty(transaction.amount.abs().toString()),
        category = transaction.category.target,
        account = transaction.fromAccount.target,
        date = transaction.date,
        id = transaction.id,
        selectedType = transaction.isIncome
            ? TransactionType.income
            : TransactionType.expense,
        status = FormzSubmissionStatus.initial,
        isValid = true, // Assume valid for edit
        actionType = ActionType.edit;

  TransactionFormState copyWith({
    TitleInput? title,
    MoneyInput? amount,
    Category? category,
    Account? account,
    DateTime? date,
    int? id,
    TransactionType? selectedType,
    FormzSubmissionStatus? status,
    TransactionResult? submittedTransaction,
    bool? isValid,
    String? errorMessage,
    bool? clearError, // Helper
    ActionType? actionType,
  }) {
    TransactionType? finalSelectedType = selectedType ?? this.selectedType;
    if (category != null && category.type != finalSelectedType) {
      finalSelectedType = category.type;
    }

    return TransactionFormState(
      title: title ?? this.title,
      amount: amount ?? this.amount,
      category: category ?? this.category,
      account: account ?? this.account,
      date: date ?? this.date,
      id: id ?? this.id,
      selectedType: finalSelectedType,
      status: status ?? this.status,
      submittedTransaction: submittedTransaction ?? this.submittedTransaction,
      isValid: isValid ?? this.isValid,
      errorMessage:
          clearError == true ? null : (errorMessage ?? this.errorMessage),
      actionType: actionType ?? this.actionType,
    );
  }

  @override
  List<Object?> get props => [
        title,
        amount,
        category,
        account,
        date,
        id,
        selectedType,
        status,
        submittedTransaction,
        isValid,
        errorMessage,
        actionType,
      ];
}

class TransactionFormCubit extends Cubit<TransactionFormState> {
  TransactionFormCubit() : super(TransactionFormState());

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

  void submitForm() {
    if (!state.isValid || state.category == null || state.account == null) {
      emit(state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: state.category == null
              ? 'Please select a category.'
              : state.account == null
                  ? 'Please select an account.'
                  : 'Invalid input.'));
      return;
    }

    emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

    try {
      double actualAmount = double.parse(state.amount.value);
      if (state.selectedType == TransactionType.expense && actualAmount > 0) {
        actualAmount = -actualAmount;
      } else if (state.selectedType == TransactionType.income &&
          actualAmount < 0) {
        actualAmount = -actualAmount;
      }

      final transaction = Transaction.createWithIds(
        id: state.id,
        title: state.title.value,
        amount: actualAmount,
        date: state.date,
        categoryId: state.category!.id,
        fromAccountId: state.account!.id,
      );

      emit(state.copyWith(
          status: FormzSubmissionStatus.success,
          submittedTransaction: TransactionResult(
            transaction: transaction,
            actionType: state.actionType,
          )));
    } on FormatException {
      emit(state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: 'Invalid amount format.'));
    } catch (e) {
      emit(state.copyWith(
          status: FormzSubmissionStatus.failure,
          errorMessage: 'An unexpected error occurred: ${e.toString()}'));
    }
  }

  void deleteTransaction() {
    if (state.actionType == ActionType.edit) {
      emit(state.copyWith(status: FormzSubmissionStatus.inProgress));

      if (state.category == null || state.account == null) {
        emit(state.copyWith(
            status: FormzSubmissionStatus.failure,
            errorMessage: 'Cannot delete, form state is incomplete.'));
        return;
      }

      try {
        double actualAmount = double.parse(state.amount.value);
        if (state.selectedType == TransactionType.expense && actualAmount > 0) {
          actualAmount = -actualAmount;
        } else if (state.selectedType == TransactionType.income &&
            actualAmount < 0) {
          actualAmount = -actualAmount;
        }

        final transaction = Transaction.createWithIds(
          id: state.id,
          title: state.title.value,
          amount: actualAmount,
          date: state.date,
          categoryId: state.category!.id,
          fromAccountId: state.account!.id,
        );

        emit(state.copyWith(
            status: FormzSubmissionStatus.success,
            actionType: ActionType.delete,
            submittedTransaction: TransactionResult(
              transaction: transaction,
              actionType: ActionType.delete,
            )));
      } catch (e) {
        emit(state.copyWith(
            status: FormzSubmissionStatus.failure,
            errorMessage: 'Failed to prepare deletion: ${e.toString()}'));
      }
    }
  }
}
