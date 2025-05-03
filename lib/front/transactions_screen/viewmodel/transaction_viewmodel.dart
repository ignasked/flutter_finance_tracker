import 'package:equatable/equatable.dart';
import 'package:flutter/material.dart';

/// ViewModel for displaying a transaction in the list.
class TransactionViewModel extends Equatable {
  final int id; // Keep original ID for actions
  final String title;
  final String displayAmount;
  final String categoryName;
  final Color categoryColor;
  final IconData categoryIcon;
  final String displayDate; // Formatted date string
  final DateTime date; // --- ADDED: Original date for sorting/grouping ---
  final bool isIncome;
  final String accountName;

  const TransactionViewModel({
    required this.id,
    required this.title,
    required this.displayAmount,
    required this.categoryName,
    required this.categoryColor,
    required this.categoryIcon,
    required this.displayDate,
    required this.date, // --- ADDED ---
    required this.isIncome,
    required this.accountName,
  });

  @override
  List<Object?> get props => [
        id,
        title,
        displayAmount,
        categoryName,
        categoryColor,
        categoryIcon,
        displayDate,
        date, // --- ADDED ---
        isIncome,
        accountName,
      ];
}
