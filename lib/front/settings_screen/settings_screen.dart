import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/models/account.dart';
import 'package:money_owl/backend/models/category.dart';
import 'package:money_owl/backend/repositories/account_repository.dart';
import 'package:money_owl/backend/repositories/category_repository.dart';
import 'package:money_owl/backend/repositories/transaction_repository.dart';
import 'package:money_owl/backend/utils/currency_utils.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/auth/auth_bloc/auth_bloc.dart';
import 'package:money_owl/front/auth/auth_screen.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';
import 'package:money_owl/front/settings_screen/account_management_screen.dart';
import 'package:money_owl/front/settings_screen/cubit/importer_cubit.dart';
import 'package:money_owl/front/settings_screen/category_management_screen.dart';
import '../common/loading_widget.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/services/sync_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final dataManagementCubit = context.watch<DataManagementCubit>();
    final enabledCategories = dataManagementCubit.getEnabledCategoriesCache();
    final enabledAccounts = dataManagementCubit.getEnabledAccountsCache();

    return BlocListener<ImporterCubit, ImporterState>(
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
              _buildSectionHeader('Account'),
              BlocBuilder<AuthBloc, AuthState>(builder: (context, state) {
                if (state.status == AuthStatus.authenticated) {
                  return Column(
                    children: [
                      _buildSyncButton(context),
                      const SizedBox(height: AppStyle.paddingSmall),
                      _buildSettingsListTile(
                        context: context,
                        icon: Icons.logout,
                        title: 'Logout from Cloud Sync',
                        onTap: () {
                          _showLogoutConfirmation(context);
                        },
                      ),
                    ],
                  );
                } else {
                  return _buildSettingsListTile(
                    context: context,
                    icon: Icons.login,
                    title: 'Login / Sign Up for Cloud Sync',
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const AuthScreen(),
                        ),
                      );
                    },
                  );
                }
              }),
              const SizedBox(height: AppStyle.paddingMedium),
              const Divider(
                  height: AppStyle.paddingMedium, color: AppStyle.dividerColor),
              _buildSectionHeader('Preferences'),
              _buildCurrencySelector(context),
              const SizedBox(height: AppStyle.paddingSmall),
              _buildDefaultCategorySelector(
                  context, enabledCategories, Defaults().defaultCategory),
              const SizedBox(height: AppStyle.paddingSmall),
              _buildDefaultAccountSelector(
                  context, enabledAccounts, Defaults().defaultAccount),
              const SizedBox(height: AppStyle.paddingSmall),
              const Divider(
                  height: AppStyle.paddingMedium, color: AppStyle.dividerColor),
              _buildSectionHeader('Management'),
              _buildSettingsListTile(
                context: context,
                icon: Icons.category_outlined,
                title: 'Manage Categories',
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const CategoryManagementScreen(),
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
                      builder: (_) => const AccountManagementScreen(),
                    ),
                  );
                },
              ),
              const SizedBox(height: AppStyle.paddingSmall),
              const Divider(
                  height: AppStyle.paddingMedium, color: AppStyle.dividerColor),
              _buildSectionHeader('Data Management'),
              _buildImportButton(),
              const SizedBox(height: AppStyle.paddingSmall),
              _buildExportButton(),
              const SizedBox(height: AppStyle.paddingSmall),
              _buildDeleteAllDataButton(context),
              const SizedBox(height: AppStyle.paddingLarge),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSyncButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () async {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text('Starting manual sync...',
                  style: AppStyle.bodyText
                      .copyWith(color: ColorPalette.onPrimary)),
              backgroundColor: AppStyle.primaryColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(
                  borderRadius:
                      BorderRadius.circular(AppStyle.borderRadiusMedium)),
              margin: const EdgeInsets.all(AppStyle.paddingSmall),
            ),
          );
        try {
          await context.read<SyncService>().syncAll();
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Manual sync successful!',
                    style: AppStyle.bodyText
                        .copyWith(color: ColorPalette.onPrimary)),
                backgroundColor: AppStyle.incomeColor,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium)),
                margin: const EdgeInsets.all(AppStyle.paddingSmall),
              ),
            );
          await context.read<DataManagementCubit>().refreshData();
        } catch (e) {
          print("Error during manual sync button press: $e");
          if (!context.mounted) return;
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(
              SnackBar(
                content: Text('Manual sync failed. Error: $e',
                    style: AppStyle.bodyText
                        .copyWith(color: ColorPalette.onError)),
                backgroundColor: ColorPalette.errorContainer,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium)),
                margin: const EdgeInsets.all(AppStyle.paddingSmall),
                duration: const Duration(seconds: 6),
              ),
            );
        }
      },
      style: AppStyle.primaryButtonStyle,
      icon: const Icon(Icons.sync, color: ColorPalette.onPrimary),
      label: const Text("Sync with Cloud"),
    );
  }

  Future<void> _showLogoutConfirmation(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: AppStyle.cardColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppStyle.borderRadiusMedium),
        ),
        title: const Text('Confirm Logout', style: AppStyle.heading2),
        content: const Text('Are you sure you want to log out?',
            style: AppStyle.bodyText),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            style: AppStyle.textButtonStyle,
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppStyle.dangerButtonStyle.copyWith(
              backgroundColor: WidgetStateProperty.all(AppStyle.secondaryColor),
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirm == true && context.mounted) {
      context.read<AuthBloc>().add(AuthLogoutRequested());
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Logging out...',
                style:
                    AppStyle.bodyText.copyWith(color: ColorPalette.onPrimary)),
            backgroundColor: AppStyle.primaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppStyle.borderRadiusMedium)),
            margin: const EdgeInsets.all(AppStyle.paddingSmall),
          ),
        );
    }
  }

  Widget _buildSectionHeader(String title, {IconData? icon}) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppStyle.paddingMedium, bottom: AppStyle.paddingSmall),
      child: Row(
        children: [
          if (icon != null) ...[
            Icon(icon, color: AppStyle.secondaryColor, size: 20),
            const SizedBox(width: AppStyle.paddingSmall),
          ],
          Expanded(
            child: Text(title, style: AppStyle.heading2),
          ),
        ],
      ),
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
                      .filteredTransactions;
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
              : const Icon(Icons.import_export, color: ColorPalette.onPrimary),
          label: const Text("Export Data"),
        );
      },
    );
  }

  Widget _buildDeleteAllDataButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAllDataConfirmation(context),
      style: AppStyle.dangerButtonStyle,
      icon: const Icon(Icons.delete_forever_outlined,
          color: ColorPalette.onPrimary),
      label: const Text("Delete All My Data"),
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
              : const Icon(Icons.import_export, color: ColorPalette.onPrimary),
          label: const Text("Import Data"),
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
          context.read<DataManagementCubit>().recalculateSummary();
        }
      },
      dropdownColor: AppStyle.cardColor,
      icon:
          const Icon(Icons.arrow_drop_down, color: AppStyle.textColorSecondary),
    );
  }

  Widget _buildDefaultCategorySelector(BuildContext context,
      List<Category> enabledCategories, Category? currentDefault) {
    if (enabledCategories.isEmpty) {
      return const ListTile(
          title: Text('No enabled categories available for default selection.',
              style: AppStyle.captionStyle));
    }

    Category? valueFromList;
    try {
      valueFromList = enabledCategories.firstWhere(
        (cat) => cat.id == Defaults().defaultCategoryId,
      );
    } catch (e) {
      print(
          "Warning: Default category ID ${Defaults().defaultCategoryId} not found in enabled categories list.");
      valueFromList = null;
    }

    return DropdownButtonFormField<Category>(
      value: valueFromList,
      decoration: AppStyle.getInputDecoration(labelText: 'Default Category'),
      items: enabledCategories.map((category) {
        return DropdownMenuItem(
          value: category,
          child: Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: Text(
                  category.title,
                  style: AppStyle.bodyText,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          Defaults().setDefaultCategoryInstance(value);
          Defaults().saveDefaults();
        }
      },
      dropdownColor: AppStyle.cardColor,
      icon:
          const Icon(Icons.arrow_drop_down, color: AppStyle.textColorSecondary),
      isExpanded: true,
      selectedItemBuilder: (context) {
        return enabledCategories.map<Widget>((category) {
          return Row(
            children: [
              Icon(category.icon, color: category.color, size: 20),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: Text(
                  category.title,
                  style: AppStyle.bodyText,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }).toList();
      },
    );
  }

  Widget _buildDefaultAccountSelector(BuildContext context,
      List<Account> enabledAccounts, Account? currentDefault) {
    if (enabledAccounts.isEmpty) {
      return const ListTile(
          title: Text('No enabled accounts available for default selection.',
              style: AppStyle.captionStyle));
    }

    Account? valueFromList;
    try {
      valueFromList = enabledAccounts.firstWhere(
        (acc) => acc.id == Defaults().defaultAccountId,
      );
    } catch (e) {
      print(
          "Warning: Default account ID ${Defaults().defaultAccountId} not found in enabled accounts list.");
      valueFromList = null;
    }

    return DropdownButtonFormField<Account>(
      value: valueFromList,
      decoration: AppStyle.getInputDecoration(labelText: 'Default Account'),
      items: enabledAccounts.map((account) {
        return DropdownMenuItem(
          value: account,
          child: Row(
            children: [
              Icon(
                IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Color(account.colorValue),
                size: 20,
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: Text(
                  account.name,
                  style: AppStyle.bodyText,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const SizedBox(width: AppStyle.paddingMedium),
              Text(
                account.currency,
                style: AppStyle.captionStyle,
              ),
            ],
          ),
        );
      }).toList(),
      onChanged: (value) {
        if (value != null) {
          Defaults().setDefaultAccountInstance(value);
        }
      },
      dropdownColor: AppStyle.cardColor,
      icon:
          const Icon(Icons.arrow_drop_down, color: AppStyle.textColorSecondary),
      isExpanded: true,
      selectedItemBuilder: (context) {
        return enabledAccounts.map<Widget>((account) {
          return Row(
            children: <Widget>[
              Icon(
                IconData(account.iconCodePoint, fontFamily: 'MaterialIcons'),
                color: Color(account.colorValue),
                size: 20,
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              Expanded(
                child: Text(
                  account.name,
                  style: AppStyle.bodyText,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          );
        }).toList();
      },
    );
  }

  Future<void> _handleImport(BuildContext context) async {
    if (!context.mounted) return;

    final txCubit = context.read<DataManagementCubit>();
    final importerCubit = context.read<ImporterCubit>();

    final existingTransactions = txCubit.state.filteredTransactions;

    final availableCategories = txCubit.state.allCategories;
    final availableAccounts = txCubit.state.allAccounts;

    final newTransactions = await importerCubit.importTransactions(
      existingTransactions,
      false,
      availableCategories: availableCategories,
      availableAccounts: availableAccounts,
    );

    if (newTransactions == null && importerCubit.state.duplicates.isNotEmpty) {
      if (!context.mounted) return;
      await _showDuplicatesDialog(
          context, availableCategories, availableAccounts);
    } else if (newTransactions != null && newTransactions.isNotEmpty) {
      if (context.mounted) {
        showLoadingPopup(context, message: 'Importing data...');
      }
      await txCubit.addTransactions(newTransactions);
      await txCubit.refreshData();
      //await txCubit.refreshData();
      if (context.mounted) {
        hideLoadingPopup(context);
      }
    }
  }

  Future<void> _showDuplicatesDialog(
    BuildContext context,
    List<Category> availableCategories,
    List<Account> availableAccounts,
  ) async {
    if (!context.mounted) return;

    final txCubit = context.read<DataManagementCubit>();
    final txRepo = context.read<TransactionRepository>();
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
        txCubit.state.filteredTransactions,
        true,
        availableCategories: availableCategories,
        availableAccounts: availableAccounts,
      );
    } else if (result == 'non-duplicates') {
      final allImportedTransactions = await importerCubit.importTransactions(
        txCubit.state.filteredTransactions,
        false,
        availableCategories: availableCategories,
        availableAccounts: availableAccounts,
      );

      if (allImportedTransactions != null) {
        final existingIds =
            List.from(txCubit.state.allTransactions).map((tx) => tx.id).toSet();
        transactionsToAdd = allImportedTransactions
            .where((tx) => !existingIds.contains(tx.id))
            .toList();
      }
    }

    if (!context.mounted) return;

    if (transactionsToAdd != null && transactionsToAdd.isNotEmpty) {
      await txRepo.putMany(transactionsToAdd.cast());
      await txCubit.refreshData();
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

  Future<void> _showDeleteAllDataConfirmation(BuildContext context) async {
    final importerCubit = context.read<ImporterCubit>();
    final dataCubit = context.read<DataManagementCubit>();
    final txRepo = context.read<TransactionRepository>();
    final catRepo = context.read<CategoryRepository>();
    final accRepo = context.read<AccountRepository>();

    await _showDeleteConfirmationDialog(
      context: context,
      title: 'Delete All Your Data?',
      content:
          'This action cannot be undone and will delete all your transactions, custom categories, and accounts. Are you sure?',
      onConfirm: () async {
        if (!context.mounted) return;
        showLoadingPopup(context, message: 'Deleting data...');

        try {
          await importerCubit.deleteAllData(
            txRepo,
            catRepo,
            accRepo,
            dataCubit,
          );
        } catch (e) {
          print("Error caught during deleteAllData in UI: $e");
        } finally {
          if (context.mounted) {
            hideLoadingPopup(context);
          }
        }
      },
    );
  }
}

extension TransactionCubitCurrencyUpdate on DataManagementCubit {
  void updateDefaultCurrency() {
    recalculateSummary();
  }
}
