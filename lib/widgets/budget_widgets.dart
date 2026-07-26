import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/category_provider.dart';

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
        color: const Color(0xFFFEE2E2),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFFECACA)),
      ),
      child: Row(
        children: [
          const Icon(Icons.warning_amber_rounded,
              color: AppTheme.danger, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              'Over budget in: ${overCategories.join(', ')}',
              style: const TextStyle(color: Color(0xFFB91C1C), fontSize: 13),
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
    final visual = context.read<CategoryProvider>().visualForValue(category);
    final color = visual.color;
    final over = limit != null && spent > limit!;
    final pct = (limit != null && limit! > 0)
        ? (spent / limit!).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppTheme.glassRowFill,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: over ? const Color(0xFFFECACA) : AppTheme.border,
          ),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CategoryIconBadge(
                  assetPath: visual.assetPath,
                  background: color,
                  size: 30,
                ),
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
                      color: over ? AppTheme.danger : AppTheme.textPrimary,
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
                    over ? AppTheme.danger : color,
                  ),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                over
                    ? 'Over by ${_fmt.format(spent - limit!)}'
                    : '${_fmt.format(limit! - spent)} remaining',
                style: TextStyle(
                  color: over ? AppTheme.danger : AppTheme.textMuted,
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
