import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:money_owl/backend/utils/app_style.dart';
import 'package:money_owl/backend/utils/defaults.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_cubit.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';
import 'package:money_owl/front/shared/data_management_cubit/data_management_cubit.dart';

class TransactionSummaryDisplay extends StatelessWidget {
  const TransactionSummaryDisplay({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<DataManagementCubit, DataManagementState>(
      buildWhen: (prev, curr) => prev.summary != curr.summary,
      builder: (context, state) {
        FilterState filterState = context.read<FilterCubit>().state;
        final currencySymbol =
            filterState.selectedAccount?.currencySymbolOrCurrency ??
                Defaults().defaultCurrencySymbol;

        return Padding(
          // Reduced vertical padding as it's now a single row
          padding: const EdgeInsets.symmetric(vertical: AppStyle.paddingSmall),
          child: Row(
            // Distribute the 3 items evenly across the row
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            crossAxisAlignment:
                CrossAxisAlignment.center, // Align items vertically center
            children: [
              // --- Balance Figure ---
              // Use Flexible or Expanded if you want them to take up equal width
              Flexible(
                flex: 5,
                child: _buildSummaryFigure(
                  label: 'Balance',
                  amountString: state.summary.balanceString,
                  currencySymbol: currencySymbol,
                  // Style for balance - maybe slightly more prominent?
                  style: AppStyle.titleStyle.copyWith(
                    // Using titleStyle instead of heading2 for compactness
                    fontWeight: FontWeight.w600, // Make it boldish
                    color: AppStyle.textColorPrimary,
                  ),
                  // Optional: Add an icon for balance
                  icon: Icons.account_balance_wallet_outlined,
                  iconColor: AppStyle.primaryColor, // Or textColorSecondary
                ),
              ),

              _buildVerticalDivider(),

              // --- Income Figure ---
              Flexible(
                flex: 2,
                child: _buildSummaryFigure(
                  label: '',
                  amountString: state.summary.totalIncomeString,
                  currencySymbol: currencySymbol,
                  style: AppStyle.amountIncomeStyle,
                  icon: Icons.arrow_upward,
                  iconColor: AppStyle.incomeColor,
                ),
              ),

              _buildVerticalDivider(),

              // --- Expense Figure ---
              Flexible(
                flex: 2,
                child: _buildSummaryFigure(
                  label: '',
                  amountString: state.summary.totalExpensesString,
                  currencySymbol: currencySymbol,
                  style: AppStyle.amountExpenseStyle,
                  icon: Icons.arrow_downward,
                  iconColor: AppStyle.expenseColor,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

// Helper widget to build the Income/Expense figures consistently
  Widget _buildSummaryFigure({
    required String label,
    required String amountString,
    required String currencySymbol,
    required TextStyle style,
    required IconData icon,
    required Color iconColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min, // Take minimum vertical space
      children: [
        Row(
          // Icon and Label row
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: iconColor, size: 16),
            const SizedBox(width: AppStyle.paddingXSmall),
            Text(
              label,
              style: AppStyle.captionStyle,
            ),
          ],
        ),
        const SizedBox(height: AppStyle.paddingXSmall), // Small gap
        Text(
          '$amountString $currencySymbol',
          style: style,
          overflow: TextOverflow.ellipsis, // Prevent overflow on small screens
          maxLines: 1,
        ),
      ],
    );
  }

  // Helper for the Vertical Divider
  Widget _buildVerticalDivider() {
    return SizedBox(
      height: 35, // Adjust height to visually fit between the text lines
      child: VerticalDivider(
        color:
            AppStyle.dividerColor.withOpacity(0.5), // Make it slightly subtle
        width: AppStyle.paddingMedium, // Give it some horizontal space
        thickness: 1,
      ),
    );
  }
}
