import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/front/receipt_scan/bulk_add/cubit/bulk_transactions_cubit.dart';
import 'package:money_owl/front/transaction_form_screen/widgets/account_dropdown.dart';
import 'package:money_owl/front/transactions_screen/widgets/transaction_list_widget.dart';

class BulkAddTransactionsScreen extends StatelessWidget {
  final String transactionName;
  final DateTime date;
  final double totalExpensesFromReceipt;
  final List<Transaction> transactions;
  final CategoryRepository categoryRepository;
  final AccountRepository accountRepository;

  const BulkAddTransactionsScreen({
    Key? key,
    required this.transactionName,
    required this.date,
    required this.totalExpensesFromReceipt,
    required this.transactions,
    required this.categoryRepository,
    required this.accountRepository,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => BulkTransactionsCubit(
        transactions: transactions,
        storeName: transactionName,
        receiptDate: date,
        receiptTotalAmount: totalExpensesFromReceipt,
        categoryRepository: categoryRepository,
        accountRepository: accountRepository,
      ),
      child: Scaffold(
        appBar: AppBar(
          title: Text('Review: $transactionName'),
          actions: [
            BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
              builder: (context, state) {
                return Row(
                  children: [
                    if (state.discountsApplied ||
                        state.transactions.length !=
                            state.originalTransactions.length)
                      IconButton(
                        icon: const Icon(Icons.restore),
                        tooltip: 'Restore Original',
                        onPressed: () => context
                            .read<BulkTransactionsCubit>()
                            .restoreOriginalTransactions(),
                      ),
                    IconButton(
                      icon: const Icon(Icons.merge_type),
                      tooltip: 'Merge by Category',
                      onPressed: () => context
                          .read<BulkTransactionsCubit>()
                          .mergeTransactionsByCategory(),
                    ),
                    if (!state.discountsApplied)
                      IconButton(
                        icon: const Icon(Icons.discount_outlined),
                        tooltip: 'Apply Discounts',
                        onPressed: () => context
                            .read<BulkTransactionsCubit>()
                            .processDiscounts(),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
        body: BlocBuilder<BulkTransactionsCubit, BulkTransactionsState>(
          builder: (context, state) {
            return Column(
              children: [
                _buildHeader(context, state),
                Expanded(
                  child: TransactionListWidget(
                    transactions: state.displayedTransactions,
                    groupByMonth: false,
                    isBulkAddContext: true,
                  ),
                ),
              ],
            );
          },
        ),
        floatingActionButton: Builder(
          builder: (buttonContext) {
            return FloatingActionButton.extended(
              onPressed: () {
                Navigator.pop(
                    buttonContext,
                    buttonContext
                        .read<BulkTransactionsCubit>()
                        .state
                        .transactions);
              },
              icon: const Icon(Icons.check),
              label: const Text('Add Transactions'),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, BulkTransactionsState state) {
    final cubit = context.read<BulkTransactionsCubit>();
    final dateFormat = DateFormat.yMMMd();

    return Padding(
      padding: const EdgeInsets.all(AppStyle.paddingMedium),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  icon: const Icon(Icons.calendar_today, size: 18),
                  label: Text(dateFormat.format(state.selectedDate)),
                  style: ElevatedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16.0),
                    textStyle: AppStyle.bodyText,
                  ),
                  onPressed: () async {
                    final DateTime? pickedDate = await showDatePicker(
                      context: context,
                      initialDate: state.selectedDate,
                      firstDate: DateTime(DateTime.now().year - 5),
                      lastDate: DateTime(DateTime.now().year + 5),
                    );
                    if (pickedDate != null &&
                        pickedDate != state.selectedDate) {
                      cubit.setSelectedDate(pickedDate);
                    }
                  },
                ),
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: AccountDropdown(
                  selectedAccount: state.selectedAccount,
                  accounts: cubit.allAccounts,
                  onChanged: (account) => cubit.setSelectedAccount(account),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppStyle.paddingMedium),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Receipt Total: ${state.receiptTotalAmount.toStringAsFixed(2)}',
                style: AppStyle.captionStyle,
              ),
              Text(
                'Calculated Total: ${state.calculatedTotalExpenses.toStringAsFixed(2)}',
                style: AppStyle.bodyText.copyWith(fontWeight: FontWeight.bold),
              ),
            ],
          ),
          if ((state.receiptTotalAmount - state.calculatedTotalExpenses).abs() >
              0.01)
            Padding(
              padding: const EdgeInsets.only(top: AppStyle.paddingSmall),
              child: Text(
                'Warning: Calculated total does not match receipt total.',
                style: AppStyle.captionStyle.copyWith(color: Colors.orange),
                textAlign: TextAlign.center,
              ),
            ),
        ],
      ),
    );
  }
}
