import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/widgets/glass.dart';

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
  final String? selectedAccount;

  const SummaryCard({
    super.key,
    required this.monthlyTotal,
    required this.transactionCount,
    required this.selectedMonth,
    required this.isCurrentMonth,
    required this.onPreviousMonth,
    required this.onNextMonth,
    this.selectedCategory,
    this.selectedAccount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: AppConstants.currencyLocale,
      symbol: AppConstants.currencySymbol,
    );
    final monthLabel = DateFormat('MMMM yyyy').format(selectedMonth);

    // Reflect whichever filters are active (category and/or account) in the
    // heading, e.g. "FOOD · CASH SPENDING". Empty → the plain month total.
    final activeFilters = [
      if (selectedCategory != null) selectedCategory!,
      if (selectedAccount != null) selectedAccount!,
    ];
    final spendingLabel = activeFilters.isEmpty
        ? 'TOTAL SPENDING'
        : '${activeFilters.join(' · ').toUpperCase()} SPENDING';
    final plural = transactionCount == 1 ? '' : 's';
    final countLabel = activeFilters.isEmpty
        ? '$transactionCount transaction$plural this month'
        : '$transactionCount matching transaction$plural';

    return HeroGlassCard(
      margin: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      padding: EdgeInsets.zero,
      borderRadius: 18,
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
                      color: AppTheme.onGlass,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
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
                    disabledForegroundColor: AppTheme.onGlassFaint,
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
                  spendingLabel,
                  style: TextStyle(
                    color: AppTheme.onGlassMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 0.5,
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
                  countLabel,
                  style: TextStyle(color: AppTheme.onGlassMuted, fontSize: 12),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
