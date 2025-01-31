import 'package:pvp_projektas/backend/objectbox_repository/ObjectBox.dart';
import 'package:objectbox/objectbox.dart';
import 'package:pvp_projektas/backend/models/transaction.dart'

class TransactionRepository{
   final ObjectBox objectbox;

   TransactionRepository(this.objectbox);

  List<Transaction> getTransactions(){
    return objectbox.store.box<Transaction>().getAll();
  }

   void addTransaction(Transaction transaction) {
     objectbox.store.box<Transaction>().put(transaction);
   }

   void updateTransaction(Transaction transaction) {
     objectbox.store.box<Transaction>().put(transaction);
   }

   void deleteTransaction(int id) {
     objectbox.store.box<Transaction>().remove(id);
   }
}