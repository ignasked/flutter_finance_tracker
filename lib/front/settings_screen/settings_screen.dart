import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/utils/currency_utils.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart';
import 'package:money_owl/front/transactions_screen/cubit/transactions_cubit.dart';
import 'package:money_owl/front/settings_screen/account_management_screen.dart';
import 'package:money_owl/front/settings_screen/cubit/csv_cubit.dart';
import 'package:money_owl/front/receipt_scan_screen/receipt_analyzer_widget.dart';
import 'package:money_owl/front/settings_screen/category_management_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../common/loading_widget.dart';
import 'package:money_owl/backend/utils/app_style.dart';

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
              SnackBar(
                content: Text(state.error!, style: AppStyle.bodyText),
                backgroundColor: AppStyle.expenseColor.withOpacity(0.8),
              ),
            );
          }
        },
        child: Scaffold(
          appBar: AppBar(
            title: const Text('Settings', style: AppStyle.heading2),
            backgroundColor: AppStyle.primaryColor,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyle.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Data Management', style: AppStyle.heading2),
                const SizedBox(height: AppStyle.paddingSmall),
                _buildExportButton(),
                _buildDeleteAllButton(context),
                ElevatedButton.icon(
                  onPressed: () =>
                      _showDeleteAllCategoriesConfirmation(context),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.expenseColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                        horizontal: AppStyle.paddingLarge,
                        vertical: AppStyle.paddingMedium / 1.2),
                    textStyle: AppStyle.buttonTextStyle,
                    shape: RoundedRectangleBorder(
                      borderRadius:
                          BorderRadius.circular(AppStyle.paddingSmall),
                    ),
                  ),
                  icon: const Icon(Icons.delete_sweep),
                  label: const Text("Delete All Categories"),
                ),
                _buildImportButton(),
                const Divider(
                    height: AppStyle.paddingLarge,
                    color: AppStyle.dividerColor),
                const Text('Preferences', style: AppStyle.heading2),
                const SizedBox(height: AppStyle.paddingSmall),
                _buildCurrencySelector(context),
                const Divider(
                    height: AppStyle.paddingLarge,
                    color: AppStyle.dividerColor),
                const Text(
                  'AI Financial Advisor',
                  style: AppStyle.heading2,
                ),
                ListTile(
                  title: const Text('Ask AI Financial Advisor',
                      style: AppStyle.titleStyle),
                  trailing: const Icon(Icons.arrow_forward,
                      color: AppStyle.primaryColor),
                  onTap: () async {
                    showLoadingPopup(context,
                        message: 'Analyzing your data...');

                    final transactions = context
                        .read<TransactionsCubit>()
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
                              width: 40,
                              height: 40,
                            ),
                            const SizedBox(width: AppStyle.paddingSmall),
                            const Text('Financial Analysis',
                                style: AppStyle.heading2),
                          ],
                        ),
                        content: SizedBox(
                          width: MediaQuery.of(context).size.width * 0.9,
                          height: MediaQuery.of(context).size.height * 0.7,
                          child: Scrollbar(
                            thumbVisibility: true,
                            child: Markdown(
                              data: analysis.toString(),
                              styleSheet: MarkdownStyleSheet(
                                p: AppStyle.bodyText,
                                h1: AppStyle.heading1,
                                h2: AppStyle.heading2,
                              ),
                            ),
                          ),
                        ),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.pop(context),
                            style: AppStyle.secondaryButtonStyle,
                            child: const Text('Close'),
                          ),
                        ],
                        shape: RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(AppStyle.paddingSmall),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(
                    height: AppStyle.paddingLarge,
                    color: AppStyle.dividerColor),
                const Text(
                  'Management',
                  style: AppStyle.heading2,
                ),
                const SizedBox(height: AppStyle.paddingSmall),
                ListTile(
                  title: const Text('Manage Categories',
                      style: AppStyle.titleStyle),
                  trailing: const Icon(Icons.arrow_forward,
                      color: AppStyle.primaryColor),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => CategoryCubit(
                              context.read<CategoryRepository>(),
                              context.read<TransactionsCubit>()),
                          child: const CategoryManagementScreen(),
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  title:
                      const Text('Manage Accounts', style: AppStyle.titleStyle),
                  trailing: const Icon(Icons.arrow_forward,
                      color: AppStyle.primaryColor),
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (context) => BlocProvider(
                          create: (context) => AccountCubit(
                              context.read<AccountRepository>(),
                              context.read<TransactionsCubit>(),
                              context.read<TransactionRepository>()),
                          child: const AccountManagementScreen(),
                        ),
                      ),
                    );
                  },
                ),
                const Divider(
                    height: AppStyle.paddingLarge,
                    color: AppStyle.dividerColor),
                const Text('Account', style: AppStyle.heading2),
                const SizedBox(height: AppStyle.paddingSmall),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: Colors.white),
                  label: const Text('Logout'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppStyle.primaryColor.withOpacity(0.8),
                    foregroundColor: Colors.white,
                    // padding: AppStyle.primaryButtonStyle.padding,
                    // textStyle: AppStyle.primaryButtonStyle.textStyle,
                    // shape: AppStyle.primaryButtonStyle.shape,
                  ),
                  onPressed: () {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                  },
                ),
                const SizedBox(height: AppStyle.paddingLarge),
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
        return ElevatedButton.icon(
          onPressed: state.isLoading
              ? null
              : () {
                  final transactions = context
                      .read<TransactionsCubit>()
                      .state
                      .displayedTransactions;
                  context.read<CsvCubit>().exportTransactions(transactions);
                },
          style: AppStyle.primaryButtonStyle,
          icon: const Icon(Icons.download),
          label: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white))
              : const Text("Export CSV"),
        );
      },
    );
  }

  Widget _buildDeleteAllButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAllTransactionsConfirmation(context),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppStyle.expenseColor,
        foregroundColor: Colors.white,
        padding: const EdgeInsets.symmetric(
            horizontal: AppStyle.paddingLarge,
            vertical: AppStyle.paddingMedium / 1.2),
        textStyle: AppStyle.buttonTextStyle,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
        ),
      ),
      icon: const Icon(Icons.delete_forever),
      label: const Text("Delete All Transactions"),
    );
  }

  Widget _buildImportButton() {
    return BlocBuilder<CsvCubit, CsvState>(
      builder: (context, state) {
        return ElevatedButton.icon(
          onPressed: state.isLoading ? null : () => _handleImport(context),
          style: AppStyle.primaryButtonStyle,
          icon: const Icon(Icons.upload),
          label: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(color: Colors.white))
              : const Text("Import CSV"),
        );
      },
    );
  }

  Widget _buildCurrencySelector(BuildContext context) {
    return DropdownButtonFormField<String>(
      value: Defaults().defaultCurrency,
      decoration: InputDecoration(
        labelText: 'Default Currency',
        labelStyle: AppStyle.bodyText,
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppStyle.paddingSmall)),
        focusedBorder: OutlineInputBorder(
          borderSide:
              const BorderSide(color: AppStyle.primaryColor, width: 2.0),
          borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
        ),
      ),
      items: CurrencyUtils.predefinedCurrencies.entries
          .map((entry) => DropdownMenuItem(
                value: entry.key,
                child: Text('${entry.key} (${entry.value})',
                    style: AppStyle.bodyText),
              ))
          .toList(),
      onChanged: (value) {
        if (value != null) {
          Defaults().defaultCurrency = value;
          Defaults().defaultCurrencySymbol =
              CurrencyUtils.predefinedCurrencies[value]!;
          Defaults().saveDefaults();
          context.read<TransactionsCubit>().calculateSummary(
              context.read<TransactionsCubit>().state.displayedTransactions);
        }
      },
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    final txCubit = context.read<TransactionsCubit>();
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
    final txCubit = context.read<TransactionsCubit>();
    final csvCubit = context.read<CsvCubit>();
    final duplicatesCount = csvCubit.state.duplicates.length;

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Duplicate Transactions Found',
            style: AppStyle.heading2),
        content: Text(
            'Found $duplicatesCount duplicate transactions. What would you like to do?',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, 'cancel'),
            style: AppStyle.secondaryButtonStyle,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'all'),
            style: AppStyle.secondaryButtonStyle,
            child: const Text('Add All'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, 'non-duplicates'),
            style: AppStyle.primaryButtonStyle,
            child: const Text('Add Non-Duplicates'),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
        ),
      ),
    );

    if (!context.mounted) return;

    if (result == 'all') {
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
        final nonDuplicates = allImportedTransactions
            .where((tx) => !txCubit.state.displayedTransactions.contains(tx))
            .toList();

        txCubit.addTransactions(nonDuplicates);
      }
    }
  }

  Future<void> _showDeleteAllTransactionsConfirmation(
      BuildContext context) async {
    final txCubit = context.read<TransactionsCubit>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Transactions?', style: AppStyle.heading2),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete ALL transactions?',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppStyle.secondaryButtonStyle,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.expenseColor),
            child:
                const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
        ),
      ),
    );

    if (!context.mounted) return;

    if (confirm == true) {
      txCubit.deleteAllTransactions();
    }
  }

  Future<void> _showDeleteAllCategoriesConfirmation(
      BuildContext context) async {
    final catRepo = context.read<CategoryRepository>();

    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete All Categories?', style: AppStyle.heading2),
        content: const Text(
            'This action cannot be undone. Are you sure you want to delete ALL categories? Default categories will be recreated.',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            style: AppStyle.secondaryButtonStyle,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
                backgroundColor: AppStyle.expenseColor),
            child:
                const Text('Delete All', style: TextStyle(color: Colors.white)),
          ),
        ],
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.paddingSmall),
        ),
      ),
    );

    if (!context.mounted) return;

    if (confirm == true) {
      catRepo.removeAll();
    }
  }
}
