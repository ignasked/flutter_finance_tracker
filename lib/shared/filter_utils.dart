import 'package:money_owl/backend/models/transaction.dart';
import 'package:money_owl/front/shared/filter_cubit/filter_state.dart';

List<Transaction> applyFilters(
    List<Transaction> transactions, FilterState state) {
  List<Transaction> filtered = List.from(transactions);

  if (state.selectedAccount != null) {
    filtered = filtered
        .where((t) => t.fromAccount.target?.id == state.selectedAccount!.id)
        .toList();
  }

  if (state.selectedCategories.isNotEmpty) {
    final categoryIds = state.selectedCategories.map((c) => c.id).toSet();
    filtered = filtered
        .where((t) => categoryIds.contains(t.category.target?.id))
        .toList();
  }

  if (state.startDate != null) {
    if (state.singleDay) {
      final startOfDay = DateTime(
          state.startDate!.year, state.startDate!.month, state.startDate!.day);
      final endOfDay = startOfDay.add(const Duration(days: 1));
      filtered = filtered
          .where((t) =>
              t.date.isAtSameMomentAs(startOfDay) ||
              (t.date.isAfter(startOfDay) && t.date.isBefore(endOfDay)))
          .toList();
    } else {
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

  if (state.minAmount != null) {
    filtered =
        filtered.where((t) => t.amount.abs() >= state.minAmount!).toList();
  }

  if (state.isIncome != null) {
    filtered = filtered.where((t) => t.isIncome == state.isIncome).toList();
  }

  return filtered;
}
