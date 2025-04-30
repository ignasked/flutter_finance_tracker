import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/front/home_screen/cubit/account_transaction_cubit.dart';
import 'package:money_owl/front/settings_screen/cubit/csv_cubit.dart';
import 'package:money_owl/front/receipt_scan_screen/receipt_analyzer_widget.dart';
import 'package:money_owl/front/settings_screen/category_management_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../common/loading_widget.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => CsvCubit(),
      child: BlocListener<CsvCubit, CsvState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(state.error!)),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings'),
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Settings Screen'),
                _buildExportButton(),
                _buildDeleteAllButton(context),
                ElevatedButton(
                  onPressed: () =>
                      context.read<CategoryRepository>().removeAll(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.red,
                    foregroundColor: Colors.white,
                  ),
                  child: const Text("Delete All Categories"),
                ),
                _buildImportButton(),
                const Divider(height: 32),
                const Text(
                  'Receipt Scanner',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 16),
                const ReceiptAnalyzerWidget(),
                const Divider(),
                const Text(
                  'AI Financial Advisor',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                ListTile(
                  title: const Text('Ask AI Financial Advisor'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () async {
                    showLoadingPopup(context,
                        message: 'Analyzing your data...');

                    final transactions = context
                        .read<AccountTransactionCubit>()
                        .state
                        .displayedTransactions;
                    final csvCubit = context.read<CsvCubit>();
                    final csvData =
                        await csvCubit.exportTransactions(transactions);
                    final analysis = await MistralService.instance
                        .provideFinancialAnalysis(csvData);

                    hideLoadingPopup(context);
                    showDialog(
                      context: context,
                      builder: (context) => AlertDialog(
                        title: Row(
                          children: [
                            Image.asset(
                              'assets/icons/money_owl_transparent.png',
                              width: 50,
                              height: 50,
                            ),
                            const SizedBox(width: 7),
                            const Text('Financial Analysis'),
                          ],
                        ),
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.95,
                          height: MediaQuery.of(context).size.height * 1.0,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: Markdown(data: analysis.toString()),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Close'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const Divider(),
                ListTile(
                  title: const Text('Manage Categories'),
                  trailing: const Icon(Icons.arrow_forward),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => CategoryCubit(
                              context.read<CategoryRepository>(),
                              context.read<AccountTransactionCubit>()),
                          child: const CategoryManagementScreen(),
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildExportButton() {
    return BlocBuilder<CsvCubit, CsvState>(
      builder: (context, state) {
        return ElevatedButton(
          onPressed: state.isLoading
              ? null
              : () {
                  final transactions = context
                      .read<AccountTransactionCubit>()
                      .state
                      .displayedTransactions;
                  context.read<CsvCubit>().exportTransactions(transactions);
                },
          child: state.isLoading
              ? const CircularProgressIndicator()
              : const Text("Export CSV"),
        );
      },
    );
  }

  Widget _buildDeleteAllButton(BuildContext context) {
    return ElevatedButton(
      onPressed: () => _showDeleteConfirmation(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.red,
        foregroundColor: Colors.white,
      ),
      child: const Text("Delete All Transactions"),
    );
  }

  Widget _buildImportButton() {
    return BlocBuilder<CsvCubit, CsvState>(
      builder: (context, state) {
        return ElevatedButton(
          onPressed: state.isLoading ? null : () => _handleImport(context),
          child: state.isLoading
              ? const CircularProgressIndicator()
              : const Text("Import CSV"),
        );
      },
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    final txCubit = context.read<AccountTransactionCubit>();
    final csvCubit = context.read<CsvCubit>();

    final existingTransactions = txCubit.state.displayedTransactions;
    final newTransactions =
        await csvCubit.importTransactions(existingTransactions, false);

    if (!context.mounted) return;

    if (newTransactions == null && csvCubit.state.duplicates.isNotEmpty) {
      await _showDuplicatesDialog(context);
    } else if (newTransactions != null) {
      txCubit.addTransactions(newTransactions);
    }
  }

  Future<void> _showDuplicatesDialog(BuildContext context) async {
    final txCubit = context.read<AccountTransactionCubit>();
    final csvCubit = context.read<CsvCubit>();
    final duplicatesCount = csvCubit.state.duplicates.length;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Transactions Found'),
        content: Text(
            'Found $duplicatesCount duplicate transactions. What would you like to do?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            child: const Text('Add All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'non-duplicates'),
            child: const Text('Add Non-Duplicates'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (result == 'all') {
      // Import all transactions including duplicates
      final transactions = await csvCubit.importTransactions(
          txCubit.state.displayedTransactions, true);

      if (!context.mounted) return;

      if (transactions != null) {
        txCubit.addTransactions(transactions);
      }
    } else if (result == 'non-duplicates') {
      final allImportedTransactions = await csvCubit.importTransactions(
          txCubit.state.displayedTransactions, true);

      if (!context.mounted) return;

      if (allImportedTransactions != null) {
        // Filter out duplicates using the existing state
        final nonDuplicates = allImportedTransactions
            .where((tx) => !txCubit.state.displayedTransactions.contains(tx))
            .toList();

        txCubit.addTransactions(nonDuplicates);
      }
    }
  }

  Future<void> _showDeleteConfirmation(BuildContext context) async {
    final txCubit = context.read<AccountTransactionCubit>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Transactions'),
        content: const Text(
            'Are you sure you want to delete all transactions? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    if (confirm == true) {
      txCubit.deleteAllTransactions();
    }
  }
}
