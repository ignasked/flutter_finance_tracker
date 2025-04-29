import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:money_owl/backend/models/transaction.dart'; // For formatting

// Assume Transaction model exists:
// class Transaction { String description; String category; double amount; DateTime date; bool isExpense; ... }
// Assume categoryToIconMap and categoryToColorMap exist

Widget buildTransactionItem(BuildContext context, Transaction tx) {
  final currencyFormat = NumberFormat.currency(
      locale: 'en_US', symbol: '\$'); // Customize locale/symbol
  final dateFormat = DateFormat.MMMd(); // e.g., Oct 15

  return Card(
    margin: EdgeInsets.symmetric(horizontal: 12, vertical: 4),
    elevation: 2,
    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
    child: InkWell(
      // Make it tappable
      onTap: () {/* Navigate to details */},
      borderRadius: BorderRadius.circular(8), // Match card shape
      child: Padding(
        padding: EdgeInsets.all(12.0),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: tx.category.target?.color ?? Colors.grey,
              child: Icon(tx.category.target?.icon ?? Icons.category,
                  color: Colors.white, size: 20),
            ),
            SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    tx.description ?? '',
                    style: Theme.of(context).textTheme.titleMedium,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  SizedBox(height: 4),
                  Text(tx.category.target?.title ?? "-",
                      style: Theme.of(context).textTheme.bodySmall),
                ],
              ),
            ),
            SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '${!tx.isIncome ? '-' : '+'}${currencyFormat.format(tx.amount.abs())}',
                  style: TextStyle(
                      fontWeight: FontWeight.bold,
                      color: tx.isIncome ? Colors.redAccent : Colors.green,
                      fontSize: 16),
                ),
                SizedBox(height: 4),
                Text(dateFormat.format(tx.date),
                    style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    ),
  );
}
