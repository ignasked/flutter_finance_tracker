import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/services/mistral_service.dart';
import 'package:money_owl/backend/utils/currency_utils.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/settings_screen/account_management_screen.dart';
import 'package:money_owl/front/settings_screen/cubit/importer_cubit.dart';
import 'package:money_owl/front/settings_screen/category_management_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../common/loading_widget.dart';
import 'package:money_owl/backend/utils/app_style.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (_) => ImporterCubit(),
      child: BlocListener<ImporterCubit, ImporterState>(
        listener: (context, state) {
          if (state.error != null) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.error!,
                      style: AppStyle.bodyText
                          .copyWith(color: ColorPalette.onError)),
                  backgroundColor: ColorPalette.errorContainer,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium),
                  ),
                  margin: const EdgeInsets.all(AppStyle.paddingSmall),
                ),
              );
          }

          // Show success operation message if available
          if (state.lastOperation != null && !state.isLoading) {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(
                SnackBar(
                  content: Text(state.lastOperation!,
                      style: AppStyle.bodyText
                          .copyWith(color: ColorPalette.onPrimary)),
                  backgroundColor: AppStyle.incomeColor,
                  behavior: SnackBarBehavior.floating,
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium),
                  ),
                  margin: const EdgeInsets.all(AppStyle.paddingSmall),
                ),
              );

            // Clear operation message after displaying
            context.read<ImporterCubit>().clearLastOperation();
          }
        },
        child: Scaffold(
          backgroundColor: AppStyle.backgroundColor,
          appBar: AppBar(
            title: const Text('Settings'),
            backgroundColor: AppStyle.primaryColor,
            foregroundColor: ColorPalette.onPrimary,
            elevation: AppStyle.elevationSmall,
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyle.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // --- Data Management Section ---
                _buildSectionHeader('Data Management'),
                _buildExportButton(),
                const SizedBox(height: AppStyle.paddingSmall),
                _buildDeleteAllTransactionsButton(context),
                const SizedBox(height: AppStyle.paddingSmall),
                _buildDeleteAllCategoriesButton(context),
                const SizedBox(height: AppStyle.paddingSmall),
                _buildImportButton(),
                const SizedBox(height: AppStyle.paddingSmall),
                const Divider(
                    height: AppStyle.paddingMedium,
                    color: AppStyle.dividerColor),

                // --- Preferences Section ---
                _buildSectionHeader('Preferences'),
                _buildCurrencySelector(context),
                const SizedBox(height: AppStyle.paddingSmall),
                const Divider(
                    height: AppStyle.paddingMedium,
                    color: AppStyle.dividerColor),

                // --- AI Financial Advisor Section ---
                _buildSectionHeader('AI Financial Advisor'),
                _buildSettingsListTile(
                  context: context,
                  icon: Icons.auto_awesome,
                  title: 'Ask AI Financial Advisor',
                  onTap: () => _showFinancialAnalysis(context),
                ),
                const SizedBox(height: AppStyle.paddingSmall),
                const Divider(
                    height: AppStyle.paddingMedium,
                    color: AppStyle.dividerColor),

                // --- Management Section ---
                _buildSectionHeader('Management'),
                _buildSettingsListTile(
                  context: context,
                  icon: Icons.category_outlined,
                  title: 'Manage Categories',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          create: (ctx) => CategoryCubit(
                              ctx.read<CategoryRepository>(),
                              ctx.read<DataManagementCubit>()),
                          child: const CategoryManagementScreen(),
                        ),
                      ),
                    );
                  },
                ),
                _buildSettingsListTile(
                  context: context,
                  icon: Icons.account_balance_wallet_outlined,
                  title: 'Manage Accounts',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BlocProvider(
                          create: (ctx) => AccountCubit(
                              ctx.read<AccountRepository>(),
                              ctx.read<DataManagementCubit>(),
                              ctx.read<TransactionRepository>()),
                          child: const AccountManagementScreen(),
                        ),
                      ),
                    );
                  },
                ),
                const SizedBox(height: AppStyle.paddingSmall),
                const Divider(
                    height: AppStyle.paddingMedium,
                    color: AppStyle.dividerColor),

                // --- Account Section ---
                _buildSectionHeader('Account'),
                ElevatedButton.icon(
                  icon: const Icon(Icons.logout, color: ColorPalette.onPrimary),
                  label: const Text('Logout'),
                  style: AppStyle.primaryButtonStyle.copyWith(
                    backgroundColor:
                        MaterialStateProperty.all(AppStyle.secondaryColor),
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

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppStyle.paddingMedium, bottom: AppStyle.paddingSmall),
      child: Text(title, style: AppStyle.heading2),
    );
  }

  Widget _buildSettingsListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, color: AppStyle.secondaryColor),
      title: Text(title, style: AppStyle.titleStyle),
      trailing: const Icon(Icons.arrow_forward_ios,
          size: 18, color: AppStyle.textColorSecondary),
      onTap: onTap,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: AppStyle.paddingSmall),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusSmall),
      ),
    );
  }

  Widget _buildExportButton() {
    return BlocBuilder<ImporterCubit, ImporterState>(
      builder: (context, state) {
        return ElevatedButton.icon(
          onPressed: state.isLoading
              ? null
              : () {
                  final transactions = context
                      .read<DataManagementCubit>()
                      .state
                      .displayedTransactions;
                  context
                      .read<ImporterCubit>()
                      .exportTransactions(transactions);
                },
          style: AppStyle.primaryButtonStyle,
          icon: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColorPalette.onPrimary,
                  ))
              : const Icon(Icons.download, color: ColorPalette.onPrimary),
          label: const Text("Export Transactions"),
        );
      },
    );
  }

  Widget _buildDeleteAllTransactionsButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAllTransactionsConfirmation(context),
      style: AppStyle.dangerButtonStyle,
      icon: const Icon(Icons.delete_forever, color: ColorPalette.onPrimary),
      label: const Text("Delete All Transactions"),
    );
  }

  Widget _buildDeleteAllCategoriesButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAllCategoriesConfirmation(context),
      style: AppStyle.dangerButtonStyle,
      icon: const Icon(Icons.delete_sweep, color: ColorPalette.onPrimary),
      label: const Text("Delete All Categories"),
    );
  }

  Widget _buildImportButton() {
    return BlocBuilder<ImporterCubit, ImporterState>(
      builder: (context, state) {
        return ElevatedButton.icon(
          onPressed: state.isLoading ? null : () => _handleImport(context),
          style: AppStyle.primaryButtonStyle,
          icon: state.isLoading
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColorPalette.onPrimary,
                  ))
              : const Icon(Icons.upload, color: ColorPalette.onPrimary),
          label: const Text("Import Transactions"),
        );
      },
    );
  }

  Widget _buildCurrencySelector(BuildContext context) {
    final currencyItems = CurrencyUtils.predefinedCurrencies.entries
        .map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Text('${entry.key} (${entry.value})',
                  style: AppStyle.bodyText),
            ))
        .toList();

    return DropdownButtonFormField<String>(
      value: Defaults().defaultCurrency,
      decoration: AppStyle.getInputDecoration(labelText: 'Default Currency'),
      items: currencyItems,
      onChanged: (value) {
        if (value != null) {
          Defaults().defaultCurrency = value;
          Defaults().defaultCurrencySymbol =
              CurrencyUtils.predefinedCurrencies[value]!;
          Defaults().saveDefaults();
          context.read<DataManagementCubit>().updateDefaultCurrency();
        }
      },
      dropdownColor: AppStyle.cardColor,
      icon:
          const Icon(Icons.arrow_drop_down, color: AppStyle.textColorSecondary),
    );
  }

  Future<void> _showFinancialAnalysis(BuildContext context) async {
    if (!context.mounted) return;

    showLoadingPopup(context, message: 'Analyzing your data...');

    try {
      final transactions =
          context.read<DataManagementCubit>().state.displayedTransactions;
      final importerCubit = context.read<ImporterCubit>();
      final jsonData = await importerCubit.exportTransactions(transactions);

      if (!context.mounted) return;

      final analysis =
          await MistralService.instance.provideFinancialAnalysis(jsonData);

      if (!context.mounted) return;

      hideLoadingPopup(context);

      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: AppStyle.cardColor,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
          ),
          titlePadding: const EdgeInsets.fromLTRB(
              AppStyle.paddingMedium,
              AppStyle.paddingMedium,
              AppStyle.paddingMedium,
              AppStyle.paddingSmall),
          contentPadding:
              const EdgeInsets.symmetric(horizontal: AppStyle.paddingMedium),
          actionsPadding: const EdgeInsets.all(AppStyle.paddingSmall),
          title: Row(
            children: [
              Image.asset(
                'assets/icons/money_owl_transparent.png',
                width: 32,
                height: 32,
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              const Expanded(
                child: Text('Financial Analysis', style: AppStyle.heading2),
              ),
            ],
          ),
          content: SizedBox(
            width: double.maxFinite,
            height: MediaQuery.of(context).size.height * 0.6,
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                padding: const EdgeInsets.only(bottom: AppStyle.paddingMedium),
                child: MarkdownBody(
                  data: analysis.toString(),
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: AppStyle.bodyText,
                    h1: AppStyle.heading1.copyWith(fontSize: 24),
                    h2: AppStyle.heading2.copyWith(fontSize: 20),
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: AppStyle.textButtonStyle,
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      if (context.mounted) {
        hideLoadingPopup(context);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error generating analysis: $e',
                style: AppStyle.bodyText.copyWith(color: ColorPalette.onError)),
            backgroundColor: ColorPalette.errorContainer,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppStyle.borderRadiusMedium)),
            margin: const EdgeInsets.all(AppStyle.paddingSmall),
          ),
        );
      }
    }
  }

  Future<void> _handleImport(BuildContext context) async {
    if (!context.mounted) return;

    final txCubit = context.read<DataManagementCubit>();
    final importerCubit = context.read<ImporterCubit>();
    final categoryRepository = context.read<CategoryRepository>();
    final accountRepository = context.read<AccountRepository>();

    final existingTransactions = txCubit.state.displayedTransactions;

    // Get all available categories and accounts to properly map them during import
    final availableCategories = await categoryRepository.getAll();
    final availableAccounts = await accountRepository.getAll();

    final newTransactions = await importerCubit.importTransactions(
      existingTransactions,
      false,
      availableCategories: availableCategories,
      availableAccounts: availableAccounts,
    );

    if (!context.mounted) return;

    if (newTransactions == null && importerCubit.state.duplicates.isNotEmpty) {
      await _showDuplicatesDialog(
          context, availableCategories, availableAccounts);
    } else if (newTransactions != null && newTransactions.isNotEmpty) {
      txCubit.addTransactions(newTransactions);
    }
  }

  Future<void> _showDuplicatesDialog(
    BuildContext context,
    List<Category> availableCategories,
    List<Account> availableAccounts,
  ) async {
    if (!context.mounted) return;

    final txCubit = context.read<DataManagementCubit>();
    final importerCubit = context.read<ImporterCubit>();
    final duplicatesCount = importerCubit.state.duplicates.length;

    final result = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
        ),
        title: const Text('Duplicate Transactions Found',
            style: AppStyle.heading2),
        content: Text(
            'Found $duplicatesCount duplicate transactions. What would you like to do?',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'cancel'),
            style: AppStyle.textButtonStyle,
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, 'all'),
            style: AppStyle.textButtonStyle,
            child: const Text('Add All'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, 'non-duplicates'),
            style: AppStyle.primaryButtonStyle,
            child: const Text('Add Non-Duplicates'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;

    List<dynamic>? transactionsToAdd;

    if (result == 'all') {
      transactionsToAdd = await importerCubit.importTransactions(
        txCubit.state.displayedTransactions,
        true,
        availableCategories: availableCategories,
        availableAccounts: availableAccounts,
      );
    } else if (result == 'non-duplicates') {
      final allImportedTransactions = await importerCubit.importTransactions(
        txCubit.state.displayedTransactions,
        true,
        availableCategories: availableCategories,
        availableAccounts: availableAccounts,
      );

      if (allImportedTransactions != null) {
        final existingIds =
            txCubit.state.allTransactions.map((tx) => tx.id).toSet();
        transactionsToAdd = allImportedTransactions
            .where((tx) => !existingIds.contains(tx.id))
            .toList();
      }
    }

    if (!context.mounted) return;

    if (transactionsToAdd != null && transactionsToAdd.isNotEmpty) {
      txCubit.addTransactions(transactionsToAdd.cast());
    }
  }

  Future<void> _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    if (!context.mounted) return;

    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
        ),
        title: Text(title, style: AppStyle.heading2),
        content: Text(content, style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: AppStyle.textButtonStyle,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppStyle.dangerButtonStyle,
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      onConfirm();
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${title.replaceFirst('?', '')} successful.',
                style:
                    AppStyle.bodyText.copyWith(color: ColorPalette.onPrimary)),
            backgroundColor: AppStyle.incomeColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppStyle.borderRadiusMedium)),
            margin: const EdgeInsets.all(AppStyle.paddingSmall),
          ),
        );
    }
  }

  Future<void> _showDeleteAllTransactionsConfirmation(
      BuildContext context) async {
    await _showDeleteConfirmationDialog(
      context: context,
      title: 'Delete All Transactions?',
      content:
          'This action cannot be undone. Are you sure you want to delete ALL transactions?',
      onConfirm: () {
        context.read<DataManagementCubit>().deleteAllTransactions();
      },
    );
  }

  Future<void> _showDeleteAllCategoriesConfirmation(
      BuildContext context) async {
    await _showDeleteConfirmationDialog(
      context: context,
      title: 'Delete All Categories?',
      content:
          'This action cannot be undone. Are you sure you want to delete ALL categories? Default categories will be recreated.',
      onConfirm: () {
        context.read<CategoryRepository>().removeAll();
      },
    );
  }
}

extension TransactionCubitCurrencyUpdate on DataManagementCubit {
  void updateDefaultCurrency() {
    recalculateSummary();
  }
}
