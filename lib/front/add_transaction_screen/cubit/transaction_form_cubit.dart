import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:formz/formz.dart';

import '../../../backend/models/transaction.dart';
import 'package:pvp_projektas/backend/transaction_repository/transaction_repository.dart';
import 'package:pvp_projektas/front/add_transaction_screen/formz/amount_input.dart';
import 'package:pvp_projektas/front/add_transaction_screen/formz/title_input.dart';


class TransactionFormState extends Equatable {
  final TitleInput title;
  final AmountInput amount;
  final FormzStatus status;

  const TransactionFormState({
    this.title = const TitleInput.pure(),
    this.amount = const AmountInput.pure(),
    this.status = FormzStatus.pure,
  });

  const AddTransactionState({required this.transaction});

  @override
  List<Object?> get props => [transaction];

  AddTransactionState copyWith({Transaction? transaction}) {
    return AddTransactionState(
      transaction: transaction ?? this.transaction,
    );
  }
  }

class AddTransactionCubit extends Cubit<AddTransactionState> {
  final TransactionRepository transRepository;

  // Initialize with an empty or default transaction
  AddTransactionCubit(this.transRepository)
      : super(AddTransactionState(transaction: Transaction(
    id: 0,
    title: '',
    amount: 0.0,
    isIncome: false,
    category: '',
    date: DateTime.now(),
  )));


  // Load a single transaction by ID
  void loadTransactionById(int id) {
    // Fetch the transaction from the repository
    final localTransaction = transRepository.getTransaction(id);

    // Emit the updated state with the loaded transaction
    emit(state.copyWith(transaction: localTransaction));
  }

  void addTransaction() {
    //create local copy of transactions
    if(state.transaction != null) {
      Transaction trans = state.transaction!;
      transRepository.addTransaction(trans);
      emit(state.copyWith(transaction: trans));
    }
  }

  /*void updateTransaction(Transaction transaction) {
    transRepository.updateTransaction(transaction);
    loadTransactions(); // Reload transactions after updating
  }

  void deleteTransaction(int id) {
    //create local copy of transactions
    List<Transaction> transactionsList = List.from(state.transactions);
    transactionsList.removeAt(id);
    transRepository.deleteTransaction(id);
    emit(state.copyWith(transactions: transactionsList));
  }*/
}
