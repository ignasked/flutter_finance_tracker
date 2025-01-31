import 'package:bloc/bloc.dart';
import 'package:equatable/equatable.dart';

part 'add_transaction_state.dart';

class AddTransactionCubit extends Cubit<AddTransactionState> {
  AddTransactionCubit() : super(AddTransactionInitial());
}
