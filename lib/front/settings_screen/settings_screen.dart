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
// import 'package:money_owl/front/receipt_scan_screen/receipt_analyzer_widget.dart'; // Assuming not used directly here
import 'package:money_owl/front/settings_screen/category_management_screen.dart';
import 'package:flutter_markdown/flutter_markdown.dart';
import '../common/loading_widget.dart'; // Ensure this uses AppStyle too if needed
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
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar() // Hide previous snackbars
              ..showSnackBar(
                SnackBar(
                  content: Text(state.error!,
                      style: AppStyle.bodyText.copyWith(
                          color: ColorPalette
                              .onError)), // Use onError color for text
                  backgroundColor:
                      ColorPalette.errorContainer, // Use error container
                  behavior: SnackBarBehavior.floating, // More modern look
                  shape: RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(AppStyle.borderRadiusMedium),
                  ),
                  margin: const EdgeInsets.all(AppStyle.paddingSmall),
                ),
              );
          }
        },
        child: Scaffold(
          backgroundColor: AppStyle.backgroundColor, // Apply background color
          appBar: AppBar(
            title: const Text('Settings'), // Removed style, inherits from theme
            backgroundColor: AppStyle.primaryColor,
            foregroundColor:
                ColorPalette.onPrimary, // Use onPrimary for text/icons
            elevation: AppStyle.elevationSmall, // Add subtle elevation
          ),
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(AppStyle.paddingMedium),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch, // Stretch buttons
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
                const SizedBox(
                    height: AppStyle.paddingSmall), // Space before divider
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
                  icon: Icons.auto_awesome, // More relevant AI icon
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
                          // Use _ for unused context
                          create: (ctx) => CategoryCubit(
                              // Use ctx
                              ctx.read<CategoryRepository>(),
                              ctx.read<TransactionsCubit>()),
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
                          // Use _ for unused context
                          create: (ctx) => AccountCubit(
                              // Use ctx
                              ctx.read<AccountRepository>(),
                              ctx.read<TransactionsCubit>(),
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
                  // Use primary button style for consistency, adjust if needed
                  style: AppStyle.primaryButtonStyle.copyWith(
                    backgroundColor: MaterialStateProperty.all(
                        AppStyle.secondaryColor), // Muted color for logout
                  ),
                  onPressed: () {
                    context.read<AuthBloc>().add(AuthLogoutRequested());
                  },
                ),
                const SizedBox(height: AppStyle.paddingLarge), // Bottom padding
              ],
            ),
          ),
        ),
      ),
    );
  }

  // Helper to build section headers consistently
  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.only(
          top: AppStyle.paddingMedium, bottom: AppStyle.paddingSmall),
      child: Text(title, style: AppStyle.heading2),
    );
  }

  // Helper to build consistent ListTiles for settings navigation
  Widget _buildSettingsListTile({
    required BuildContext context,
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon,
          color: AppStyle.secondaryColor), // Use secondary color for icons
      title: Text(title, style: AppStyle.titleStyle),
      trailing: const Icon(
          Icons.arrow_forward_ios, // More standard iOS/Material arrow
          size: 18,
          color: AppStyle.textColorSecondary),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(
          horizontal: AppStyle.paddingSmall), // Adjust padding
      shape: RoundedRectangleBorder(
        // Optional: Add subtle border/background on hover/tap
        borderRadius: BorderRadius.circular(AppStyle.borderRadiusSmall),
      ),
      // tileColor: AppStyle.cardColor, // Optional: if you want tiles on card background
    );
  }

  // --- Button Builder Methods (Updated Styles) ---

  Widget _buildExportButton() {
    return BlocBuilder<CsvCubit, CsvState>(
      builder: (context, state) {
        return ElevatedButton.icon(
          onPressed: state.isLoading
              ? null // Disable button when loading
              : () {
                  final transactions = context
                      .read<TransactionsCubit>()
                      .state
                      .displayedTransactions;
                  context.read<CsvCubit>().exportTransactions(transactions);
                },
          style: AppStyle.primaryButtonStyle,
          icon: state.isLoading
              ? const SizedBox(
                  // Consistent loading indicator size
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: ColorPalette.onPrimary, // Use contrast color
                  ))
              : const Icon(Icons.download, color: ColorPalette.onPrimary),
          label: const Text("Export CSV"),
        );
      },
    );
  }

  Widget _buildDeleteAllTransactionsButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAllTransactionsConfirmation(context),
      style: AppStyle.dangerButtonStyle, // Use danger style
      icon: const Icon(Icons.delete_forever, color: ColorPalette.onPrimary),
      label: const Text("Delete All Transactions"),
    );
  }

  Widget _buildDeleteAllCategoriesButton(BuildContext context) {
    return ElevatedButton.icon(
      onPressed: () => _showDeleteAllCategoriesConfirmation(context),
      style: AppStyle.dangerButtonStyle, // Use danger style
      icon: const Icon(Icons.delete_sweep, color: ColorPalette.onPrimary),
      label: const Text("Delete All Categories"),
    );
  }

  Widget _buildImportButton() {
    return BlocBuilder<CsvCubit, CsvState>(
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
          label: const Text("Import CSV"),
        );
      },
    );
  }

  // --- Other Builder Methods (Updated Styles) ---

  Widget _buildCurrencySelector(BuildContext context) {
    // Get available currencies once
    final currencyItems = CurrencyUtils.predefinedCurrencies.entries
        .map((entry) => DropdownMenuItem(
              value: entry.key,
              child: Text('${entry.key} (${entry.value})',
                  style: AppStyle.bodyText),
            ))
        .toList();

    return DropdownButtonFormField<String>(
      value: Defaults().defaultCurrency,
      // Use AppStyle's input decoration
      decoration: AppStyle.getInputDecoration(labelText: 'Default Currency'),
      items: currencyItems,
      onChanged: (value) {
        if (value != null) {
          // Consider moving this logic to a Cubit/Bloc if state becomes complex
          Defaults().defaultCurrency = value;
          Defaults().defaultCurrencySymbol =
              CurrencyUtils.predefinedCurrencies[value]!;
          Defaults().saveDefaults();
          // Trigger recalculation in TransactionsCubit
          context.read<TransactionsCubit>().updateDefaultCurrency();
        }
      },
      // Style dropdown items
      dropdownColor: AppStyle.cardColor,
      icon:
          const Icon(Icons.arrow_drop_down, color: AppStyle.textColorSecondary),
    );
  }

  // --- Dialog Methods (Updated Styles) ---

  Future<void> _showFinancialAnalysis(BuildContext context) async {
    // Check if context is still mounted before async operations
    if (!context.mounted) return;

    showLoadingPopup(context, message: 'Analyzing your data...');

    try {
      final transactions =
          context.read<TransactionsCubit>().state.displayedTransactions;
      final csvCubit = context.read<CsvCubit>();
      final csvData = await csvCubit.exportTransactions(transactions);

      // Check mount status again after await
      if (!context.mounted) return;

      final analysis =
          await MistralService.instance.provideFinancialAnalysis(csvData);

      // Check mount status again after await
      if (!context.mounted) return;

      hideLoadingPopup(context); // Hide loading before showing dialog

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
            // Keep title row as is, styling is fine
            children: [
              Image.asset(
                'assets/icons/money_owl_transparent.png', // Ensure this asset exists
                width: 32, // Slightly smaller icon
                height: 32,
              ),
              const SizedBox(width: AppStyle.paddingSmall),
              const Expanded(
                // Allow title to wrap
                child: Text('Financial Analysis', style: AppStyle.heading2),
              ),
            ],
          ),
          content: SizedBox(
            // Constrain size for readability
            width: double.maxFinite, // Take available width
            height: MediaQuery.of(context).size.height * 0.6, // Adjust height
            child: Scrollbar(
              thumbVisibility: true,
              child: SingleChildScrollView(
                // Wrap Markdown in SingleChildScrollView
                padding: const EdgeInsets.only(
                    bottom: AppStyle.paddingMedium), // Padding for scrollbar
                child: MarkdownBody(
                  // Use MarkdownBody for better integration
                  data: analysis.toString(),
                  styleSheet:
                      MarkdownStyleSheet.fromTheme(Theme.of(context)).copyWith(
                    p: AppStyle.bodyText,
                    h1: AppStyle.heading1
                        .copyWith(fontSize: 24), // Adjust heading sizes
                    h2: AppStyle.heading2.copyWith(fontSize: 20),
                    // Add other styles as needed (list, code block, etc.)
                  ),
                ),
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              style: AppStyle.textButtonStyle, // Use text button style
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (e) {
      // Check mount status in catch block
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
    // Check if context is still mounted before async operations
    if (!context.mounted) return;

    final txCubit = context.read<TransactionsCubit>();
    final csvCubit = context.read<CsvCubit>();

    final existingTransactions = txCubit.state.displayedTransactions;
    // Consider adding a loading indicator here if import takes time
    final newTransactions =
        await csvCubit.importTransactions(existingTransactions, false);

    // Check mount status again after await
    if (!context.mounted) return;

    if (newTransactions == null && csvCubit.state.duplicates.isNotEmpty) {
      await _showDuplicatesDialog(context);
    } else if (newTransactions != null) {
      txCubit.addTransactions(newTransactions);
      // Show success message
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('CSV imported successfully!',
                style: AppStyle.bodyText.copyWith(
                    color: ColorPalette.onPrimary)), // Success text color
            backgroundColor:
                AppStyle.incomeColor, // Use income color for success
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppStyle.borderRadiusMedium)),
            margin: const EdgeInsets.all(AppStyle.paddingSmall),
          ),
        );
    } else if (csvCubit.state.error == null) {
      // Handle case where import resulted in no new transactions and no errors/duplicates (e.g., empty file)
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No new transactions found in the CSV file.',
                style: AppStyle.bodyText),
            backgroundColor: AppStyle.secondaryColor, // Neutral color
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppStyle.borderRadiusMedium)),
            margin: const EdgeInsets.all(AppStyle.paddingSmall),
          ),
        );
    }
    // Error case is handled by the BlocListener
  }

  Future<void> _showDuplicatesDialog(BuildContext context) async {
    // Check mount status before showing dialog
    if (!context.mounted) return;

    final txCubit = context.read<TransactionsCubit>();
    final csvCubit = context.read<CsvCubit>();
    final duplicatesCount = csvCubit.state.duplicates.length;

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
            style: AppStyle.textButtonStyle, // Use text button style
            child: const Text('Cancel'),
          ),
          TextButton(
            // Consider making "Add All" less prominent if potentially risky
            onPressed: () => Navigator.pop(dialogContext, 'all'),
            style: AppStyle.textButtonStyle,
            child: const Text('Add All'),
          ),
          ElevatedButton(
            // Primary action
            onPressed: () => Navigator.pop(dialogContext, 'non-duplicates'),
            style: AppStyle.primaryButtonStyle,
            child: const Text('Add Non-Duplicates'),
          ),
        ],
      ),
    );

    // Check mount status again after await
    if (!context.mounted) return;

    List<dynamic>?
        transactionsToAdd; // Use dynamic or specific Transaction type
    bool addSuccess = false;

    if (result == 'all') {
      transactionsToAdd = await csvCubit.importTransactions(
          txCubit.state.displayedTransactions, true);
    } else if (result == 'non-duplicates') {
      // Re-import with includeDuplicates=true to get all potential transactions
      final allImportedTransactions = await csvCubit.importTransactions(
          txCubit.state.displayedTransactions, true);

      if (allImportedTransactions != null) {
        // Filter out duplicates based on existing transactions *before* this import attempt
        final existingIds =
            txCubit.state.allTransactions.map((tx) => tx.id).toSet();
        transactionsToAdd = allImportedTransactions
            .where((tx) => !existingIds.contains(
                tx.id)) // Assuming unique IDs are reliable for duplicates
            .toList();
      }
    }

    // Check mount status again
    if (!context.mounted) return;

    if (transactionsToAdd != null && transactionsToAdd.isNotEmpty) {
      txCubit.addTransactions(transactionsToAdd.cast()); // Cast if necessary
      addSuccess = true;
    }

    // Show feedback message
    if (addSuccess) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('Transactions added successfully!',
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
    } else if (result != 'cancel') {
      // Only show 'no transactions added' if user didn't cancel
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('No new transactions were added.',
                style: AppStyle.bodyText),
            backgroundColor: AppStyle.secondaryColor,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
                borderRadius:
                    BorderRadius.circular(AppStyle.borderRadiusMedium)),
            margin: const EdgeInsets.all(AppStyle.paddingSmall),
          ),
        );
    }
  }

  Future<void> _showDeleteConfirmationDialog({
    required BuildContext context,
    required String title,
    required String content,
    required VoidCallback onConfirm,
  }) async {
    // Check mount status before showing dialog
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
            // Use ElevatedButton for the destructive action confirmation
            onPressed: () => Navigator.pop(dialogContext, true),
            style: AppStyle.dangerButtonStyle, // Use danger style for confirm
            child: const Text('Delete'), // Consistent text
          ),
        ],
      ),
    );

    // Check mount status again after await
    if (confirm == true && context.mounted) {
      onConfirm();
      // Show confirmation snackbar
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text('${title.replaceFirst('?', '')} successful.',
                style:
                    AppStyle.bodyText.copyWith(color: ColorPalette.onPrimary)),
            backgroundColor:
                AppStyle.incomeColor, // Green for success confirmation
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
        // Check mount status inside callback if needed, though less likely here
        context.read<TransactionsCubit>().deleteAllTransactions();
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
        // Optionally trigger a refresh in relevant cubits if needed
      },
    );
  }
}

// Add this extension method to TransactionsCubit if it doesn't exist
// or update your existing method for handling currency changes.
extension TransactionCubitCurrencyUpdate on TransactionsCubit {
  void updateDefaultCurrency() {
    // Re-calculate summary and potentially re-filter/reload transactions
    // based on the new default currency from Defaults().
    // This implementation depends on how your cubit manages state.
    // Example:
    recalculateSummary(); // Recalculate summary
    // You might need to re-apply filters if they depend on currency formatting
    //applyFilters();
  }
}
