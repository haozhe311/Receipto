import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';

/// Displays a spending summary card with the monthly total and transaction count.
class SummaryCard extends StatelessWidget {
  final double monthlyTotal;
  final int transactionCount;

  const SummaryCard({
    super.key,
    required this.monthlyTotal,
    required this.transactionCount,
  });

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: AppConstants.currencyLocale,
      symbol: AppConstants.currencySymbol,
    );
    final monthName = DateFormat('MMMM yyyy').format(DateTime.now());

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
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'TOTAL SPENDING',
                  style: TextStyle(
                    color: AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    letterSpacing: 1.2,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  monthName,
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
                ),
                const SizedBox(height: 12),
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
                  '$transactionCount transaction${transactionCount == 1 ? '' : 's'} this month',
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
