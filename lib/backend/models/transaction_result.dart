import 'package:pvp_projektas/backend/models/transaction.dart';
import 'package:pvp_projektas/front/add_transaction_screen/cubit/transaction_form_cubit.dart';

// Used for sending transactionList manipulation data from AddTransactionScreen to HomeScreen
class TransactionResult{
  final Transaction transaction;
  final ActionType actionType;
  final int? index; // Only  used for editing

  TransactionResult({required this.transaction, required this.actionType, this.index});
}