import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';

List<Transaction> applyFilters(
    List<Transaction> transactions, FilterState state) {
  List<Transaction> filtered = List.from(transactions);

  // Apply Account Filter
  if (state.selectedAccount != null) {
    filtered = filtered
        .where((t) => t.fromAccount.target?.id == state.selectedAccount!.id)
        .toList();
  }

  // Apply Category Filter
  if (state.selectedCategories.isNotEmpty) {
    final categoryIds = state.selectedCategories.map((c) => c.id).toSet();
    filtered = filtered
        .where((t) => categoryIds.contains(t.category.target?.id))
        .toList();
  }

  // Apply Date Filter
  if (state.startDate != null) {
    if (state.singleDay) {
      // Filter for a single day (ignore time part)
      final startOfDay = DateTime(
          state.startDate!.year, state.startDate!.month, state.startDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      filtered = filtered
          .where((t) =>
              t.date.isAtSameMomentAs(startOfDay) ||
              (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)))
          .toList();
    } else {
      // Filter for a date range (inclusive start, exclusive end for end date)
      final rangeStart = state.startDate!;
      final rangeEnd = state.endDate?.add(const Duration(days: 1));

      filtered = filtered.where((t) {
        final transactionDate = t.date;
        bool afterStart = transactionDate.isAtSameMomentAs(rangeStart) ||
            transactionDate.isAfter(rangeStart);
        bool beforeEnd = rangeEnd == null || transactionDate.isBefore(rangeEnd);
        return afterStart && beforeEnd;
      }).toList();
    }
  }

  // Apply Amount Filter (Optional)
  if (state.minAmount != null) {
    filtered =
        filtered.where((t) => t.amount.abs() >= state.minAmount!).toList();
  }

  // Apply Income/Expense Filter (Optional)
  if (state.isIncome != null) {
    filtered = filtered.where((t) => t.isIncome == state.isIncome).toList();
  }

  return filtered;
}
