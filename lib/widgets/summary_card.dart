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
  final ValueChanged<DateTime> onSelectMonth;
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
    required this.onSelectMonth,
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
                // Month label — tap to jump to any month/year.
                Expanded(
                  child: InkWell(
                    onTap: () => _openMonthPicker(context),
                    borderRadius: BorderRadius.circular(8),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            monthLabel,
                            style: const TextStyle(
                              color: AppTheme.onGlass,
                              fontSize: 14,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 2),
                          const Icon(
                            Icons.arrow_drop_down,
                            size: 20,
                            color: AppTheme.gold,
                          ),
                        ],
                      ),
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
                    color: AppTheme.textPrimary,
                    fontSize: 32,
                    fontWeight: FontWeight.w800,
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

  void _openMonthPicker(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppTheme.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _MonthPickerSheet(
        selectedMonth: selectedMonth,
        onSelect: (month) {
          Navigator.of(context).pop();
          onSelectMonth(month);
        },
      ),
    );
  }
}

/// Bottom sheet to jump to any month/year: a year stepper plus a 12-month grid.
/// Future months (beyond the current one) are disabled.
class _MonthPickerSheet extends StatefulWidget {
  final DateTime selectedMonth;
  final ValueChanged<DateTime> onSelect;

  const _MonthPickerSheet({
    required this.selectedMonth,
    required this.onSelect,
  });

  @override
  State<_MonthPickerSheet> createState() => _MonthPickerSheetState();
}

class _MonthPickerSheetState extends State<_MonthPickerSheet> {
  late int _year;

  @override
  void initState() {
    super.initState();
    _year = widget.selectedMonth.year;
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec',
    ];

    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Grab handle
            Container(
              width: 40,
              height: 4,
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: AppTheme.border,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            // Year stepper
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: () => setState(() => _year--),
                  icon: const Icon(Icons.chevron_left),
                  color: AppTheme.gold,
                ),
                Text(
                  '$_year',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                IconButton(
                  // Can't step into a year past the current one.
                  onPressed: _year >= now.year
                      ? null
                      : () => setState(() => _year++),
                  icon: const Icon(Icons.chevron_right),
                  color: AppTheme.gold,
                  disabledColor: AppTheme.onGlassFaint,
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Month grid
            GridView.count(
              crossAxisCount: 4,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 10,
              crossAxisSpacing: 10,
              childAspectRatio: 1.9,
              children: [
                for (int i = 0; i < 12; i++)
                  _MonthCell(
                    label: months[i],
                    selected: _year == widget.selectedMonth.year &&
                        i + 1 == widget.selectedMonth.month,
                    // Disable months in the future.
                    disabled: DateTime(_year, i + 1).isAfter(
                      DateTime(now.year, now.month),
                    ),
                    onTap: () => widget.onSelect(DateTime(_year, i + 1)),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _MonthCell extends StatelessWidget {
  final String label;
  final bool selected;
  final bool disabled;
  final VoidCallback onTap;

  const _MonthCell({
    required this.label,
    required this.selected,
    required this.disabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: disabled ? null : onTap,
      borderRadius: BorderRadius.circular(10),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppTheme.gold : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? AppTheme.gold : AppTheme.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: disabled
                ? AppTheme.onGlassFaint
                : selected
                    ? Colors.white
                    : AppTheme.textPrimary,
            fontSize: 14,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          ),
        ),
      ),
    );
  }
}
