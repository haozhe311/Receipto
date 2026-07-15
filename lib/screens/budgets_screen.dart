import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/budget_provider.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/widgets/budget_widgets.dart';

/// Lets the user set a monthly spending limit per category and shows
/// current-month progress against each limit, with over-budget alerts.
class BudgetsScreen extends StatefulWidget {
  const BudgetsScreen({super.key});

  @override
  State<BudgetsScreen> createState() => _BudgetsScreenState();
}

class _BudgetsScreenState extends State<BudgetsScreen> {
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
              if (budgets.hasOverBudget)
                BudgetOverBanner(
                  overCategories: budgets.overBudgetCategories,
                ),
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
                BudgetProgressRow(
                  category: cat.name,
                  limit: budgets.limitFor(cat.name),
                  spent: budgets.spentFor(cat.name),
                  onTap: () => _showSetBudgetDialog(
                    context,
                    budgets,
                    cat.name,
                    budgets.limitFor(cat.name),
                  ),
                ),
                const SizedBox(height: 10),
              ],
            ],
          );
        },
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
