import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';

final _fmt = NumberFormat.currency(
  locale: AppConstants.currencyLocale,
  symbol: AppConstants.currencySymbol,
);

/// Red banner listing categories that are over budget.
///
/// Shared by the Budgets screen and the Analytics screen so the alert looks
/// and behaves identically in both places.
class BudgetOverBanner extends StatelessWidget {
  final List<String> overCategories;

  const BudgetOverBanner({super.key, required this.overCategories});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF3D1010),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF6B2020)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: Color(0xFFFF9999), size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Over budget in: ${overCategories.join(', ')}',
              style: const TextStyle(color: Color(0xFFFF9999), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// One category's budget-progress row: name, spent / limit, and a progress bar.
///
/// [spent] is passed in by the caller so the row can reflect any month
/// (current month on the Budgets screen, the selected month on Analytics).
/// When [onTap] is provided the row is tappable (Budgets uses it to edit).
class BudgetProgressRow extends StatelessWidget {
  final String category;
  final double? limit;
  final double spent;
  final VoidCallback? onTap;

  const BudgetProgressRow({
    super.key,
    required this.category,
    required this.limit,
    required this.spent,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppConstants.categoryColors[category] ?? Colors.grey;
    final icon = AppConstants.categoryIcons[category] ?? Icons.more_horiz;
    final over = limit != null && spent > limit!;
    final pct = (limit != null && limit! > 0)
        ? (spent / limit!).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: over ? const Color(0xFF6B2020) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    category,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
                if (limit == null)
                  Text(
                    'Set budget',
                    style: TextStyle(color: AppTheme.gold, fontSize: 13),
                  )
                else
                  Text(
                    '${_fmt.format(spent)} / ${_fmt.format(limit)}',
                    style: TextStyle(
                      color: over
                          ? const Color(0xFFFF9999)
                          : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
            if (limit != null) ...[
              const SizedBox(height: 10),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: pct,
                  minHeight: 7,
                  backgroundColor: AppTheme.border,
                  valueColor: AlwaysStoppedAnimation<Color>(
                    over ? const Color(0xFFFF6B6B) : color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                over
                    ? 'Over by ${_fmt.format(spent - limit!)}'
                    : '${_fmt.format(limit! - spent)} remaining',
                style: TextStyle(
                  color: over ? const Color(0xFFFF9999) : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
