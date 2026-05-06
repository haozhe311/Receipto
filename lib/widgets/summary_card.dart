import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';

/// Displays a spending summary card with month navigation,
/// the selected month's total, and transaction count.
class SummaryCard extends StatelessWidget {
  final double monthlyTotal;
  final int transactionCount;
  final DateTime selectedMonth;
  final bool isCurrentMonth;
  final VoidCallback onPreviousMonth;
  final VoidCallback onNextMonth;
  final String? selectedCategory;

  const SummaryCard({
    super.key,
    required this.monthlyTotal,
    required this.transactionCount,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.selectedCategory,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: AppConstants.currencyLocale,
      symbol: AppConstants.currencySymbol,
    );
    final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Month navigator row
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 10, 8, 0),
            child: Row(
              children: [
                // Previous month
                IconButton(
                  onPressed: onPreviousMonth,
                  icon: const Icon(Icons.chevron_left),
                  iconSize: 22,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
                // Month label
                Expanded(
                  child: Text(
                    monthLabel,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                // Next month (disabled when viewing current month)
                IconButton(
                  onPressed: isCurrentMonth ? null : onNextMonth,
                  icon: const Icon(Icons.chevron_right),
                  iconSize: 22,
                  padding: const EdgeInsets.all(4),
                  constraints: const BoxConstraints(),
                  style: IconButton.styleFrom(
                    foregroundColor: AppTheme.gold,
                    disabledForegroundColor: const Color(0xFF555577),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),

          // Spending amount + count
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  selectedCategory != null
                      ? '${selectedCategory!.toUpperCase()} SPENDING'
                      : 'TOTAL SPENDING',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  currencyFormat.format(monthlyTotal),
                  style: const TextStyle(
                    color: AppTheme.gold,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    letterSpacing: -0.5,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  selectedCategory != null
                      ? '$transactionCount transaction${transactionCount == 1 ? '' : 's'} in $selectedCategory'
                      : '$transactionCount transaction${transactionCount == 1 ? '' : 's'} this month',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
              ],
            ),
          ),

          // Gold accent line at the bottom
          Container(
            height: 3,
            decoration: BoxDecoration(
              borderRadius: const BorderRadius.vertical(
                bottom: Radius.circular(16),
              ),
              gradient: const LinearGradient(
                colors: [AppTheme.gold, Color(0x00F4C542)],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
