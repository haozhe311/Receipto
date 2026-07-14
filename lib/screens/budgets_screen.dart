import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/budget_provider.dart';
import 'package:receipto/providers/category_provider.dart';

/// Lets the user set a monthly spending limit per category and shows
/// current-month progress against each limit, with over-budget alerts.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  @override
  void initState() {
    super.initState();
    // Refresh current-month spending each time the screen opens.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<BudgetProvider>().loadBudgets();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Budgets')),
      body: Consumer2<BudgetProvider, CategoryProvider>(
        builder: (context, budgets, categories, _) {
          if (budgets.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          // Skip the "Others" catch-all — budgeting it is rarely meaningful.
          final cats = categories.categories
              .where((c) => c.name != 'Others')
              .toList();

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (budgets.hasOverBudget) _overBudgetBanner(budgets),
              Text(
                'MONTHLY LIMITS',
                style: TextStyle(
                  color: AppTheme.gold,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Tap a category to set or edit its monthly budget.',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              const SizedBox(height: 12),
              for (final cat in cats) ...[
                _budgetRow(
                  context,
                  budgets,
                  cat.name,
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _overBudgetBanner(BudgetProvider budgets) {
    final list = budgets.overBudgetCategories.join(', ');
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
              'Over budget in: $list',
              style: const TextStyle(color: Color(0xFFFF9999), fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }

  Widget _budgetRow(
    BuildContext context,
    BudgetProvider budgets,
    String category,
  ) {
    final limit = budgets.limitFor(category);
    final spent = budgets.spentFor(category);
    final color = AppConstants.categoryColors[category] ?? Colors.grey;
    final icon = AppConstants.categoryIcons[category] ?? Icons.more_horiz;
    final over = limit != null && spent > limit;
    final pct = (limit != null && limit > 0)
        ? (spent / limit).clamp(0.0, 1.0)
        : 0.0;

    return GestureDetector(
      onTap: () => _showSetBudgetDialog(context, budgets, category, limit),
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
                    ? 'Over by ${_fmt.format(spent - limit)}'
                    : '${_fmt.format(limit - spent)} remaining',
                style: TextStyle(
                  color: over
                      ? const Color(0xFFFF9999)
                      : AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  void _showSetBudgetDialog(
    BuildContext context,
    BudgetProvider budgets,
    String category,
    double? currentLimit,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _SetBudgetDialog(
        category: category,
        currentLimit: currentLimit,
        onSave: (value) => budgets.setBudget(category, value),
        onDelete: currentLimit != null
            ? () => budgets.deleteBudget(category)
            : null,
      ),
    );
  }
}

/// Dialog for setting, editing, or removing a category budget.
class _SetBudgetDialog extends StatefulWidget {
  final String category;
  final double? currentLimit;
  final ValueChanged<double> onSave;
  final VoidCallback? onDelete;

  const _SetBudgetDialog({
    required this.category,
    required this.currentLimit,
    required this.onSave,
    required this.onDelete,
  });

  @override
  State<_SetBudgetDialog> createState() => _SetBudgetDialogState();
}

class _SetBudgetDialogState extends State<_SetBudgetDialog> {
  late final TextEditingController _controller;
  String? _error;

  @override
  void initState() {
    super.initState();
    _controller = TextEditingController(
      text: widget.currentLimit != null
          ? widget.currentLimit!.toStringAsFixed(2)
          : '',
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = double.tryParse(_controller.text.trim());
    if (value == null || value <= 0) {
      setState(() => _error = 'Enter a valid amount greater than 0');
      return;
    }
    final navigator = Navigator.of(context);
    widget.onSave(value);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('${widget.category} Budget'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Monthly limit (RM)',
          prefixText: 'RM ',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      actions: [
        if (widget.onDelete != null)
          TextButton(
            onPressed: () {
              final navigator = Navigator.of(context);
              widget.onDelete!();
              navigator.pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Remove'),
          ),
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _save,
          child: const Text('Save'),
        ),
      ],
    );
  }
}
