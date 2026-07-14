import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/goal.dart';
import 'package:receipto/providers/goal_provider.dart';

/// Savings goals: create targets, track progress, and log contributions.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<GoalProvider>().loadGoals();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Savings Goals')),
      floatingActionButton: FloatingActionButton(
        onPressed: _showAddGoalDialog,
        child: const Icon(Icons.add),
      ),
      body: Consumer<GoalProvider>(
        builder: (context, goals, _) {
          if (goals.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          if (goals.goals.isEmpty) {
            return _emptyState();
          }
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
            children: [
              for (final goal in goals.goals) ...[
                _goalCard(context, goals, goal),
                const SizedBox(height: 12),
              ],
            ],
          );
        },
      ),
    );
  }

  Widget _emptyState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.savings_outlined,
                size: 56, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'No savings goals yet',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'Tap + to create your first goal — an emergency '
              'fund, a trip, or a big purchase.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
          ],
        ),
      ),
    );
  }

  Widget _goalCard(BuildContext context, GoalProvider provider, Goal goal) {
    final done = goal.isComplete;
    final accent = done ? const Color(0xFF4CAF50) : AppTheme.gold;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  goal.name,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (done)
                const Icon(Icons.check_circle,
                    color: Color(0xFF4CAF50), size: 20),
              IconButton(
                onPressed: () => _confirmDelete(context, provider, goal),
                icon: const Icon(Icons.delete_outline, size: 20),
                color: const Color(0xFFFF6B6B),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              Text(
                _fmt.format(goal.savedAmount),
                style: TextStyle(
                  color: accent,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                '  / ${_fmt.format(goal.targetAmount)}',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
              ),
              const Spacer(),
              Text(
                '${(goal.progress * 100).toStringAsFixed(0)}%',
                style: TextStyle(
                  color: accent,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(5),
            child: LinearProgressIndicator(
              value: goal.progress,
              minHeight: 9,
              backgroundColor: AppTheme.border,
              valueColor: AlwaysStoppedAnimation<Color>(accent),
            ),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              Text(
                done
                    ? 'Goal reached! 🎉'
                    : '${_fmt.format(goal.remaining)} to go',
                style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
              ),
              if (goal.targetDate != null) ...[
                const Spacer(),
                Icon(Icons.flag_outlined,
                    size: 13, color: AppTheme.textMuted),
                const SizedBox(width: 4),
                Text(
                  DateFormat('dd MMM yyyy').format(goal.targetDate!),
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ],
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () =>
                      _showContributeDialog(context, provider, goal, false),
                  icon: const Icon(Icons.remove, size: 18),
                  label: const Text('Withdraw'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () =>
                      _showContributeDialog(context, provider, goal, true),
                  icon: const Icon(Icons.add, size: 18),
                  label: const Text('Add'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _confirmDelete(
    BuildContext context,
    GoalProvider provider,
    Goal goal,
  ) {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Goal'),
        content: Text('Delete "${goal.name}"? This cannot be undone.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(ctx).pop();
              if (goal.id != null) provider.deleteGoal(goal.id!);
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  void _showAddGoalDialog() {
    showDialog<void>(
      context: context,
      builder: (_) => _AddGoalDialog(
        onSave: (name, target, date) {
          context.read<GoalProvider>().addGoal(
                name: name,
                targetAmount: target,
                targetDate: date,
              );
        },
      ),
    );
  }

  void _showContributeDialog(
    BuildContext context,
    GoalProvider provider,
    Goal goal,
    bool isAdd,
  ) {
    showDialog<void>(
      context: context,
      builder: (_) => _ContributeDialog(
        isAdd: isAdd,
        goalName: goal.name,
        onSubmit: (amount) =>
            provider.contribute(goal, isAdd ? amount : -amount),
      ),
    );
  }
}

// ── Add-goal dialog ─────────────────────────────────────────────────────────

class _AddGoalDialog extends StatefulWidget {
  final void Function(String name, double target, DateTime? date) onSave;

  const _AddGoalDialog({required this.onSave});

  @override
  State<_AddGoalDialog> createState() => _AddGoalDialogState();
}

class _AddGoalDialogState extends State<_AddGoalDialog> {
  final _nameController = TextEditingController();
  final _targetController = TextEditingController();
  DateTime? _targetDate;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _targetDate ?? now.add(const Duration(days: 90)),
      firstDate: now,
      lastDate: DateTime(now.year + 20),
    );
    if (picked != null) setState(() => _targetDate = picked);
  }

  void _save() {
    final name = _nameController.text.trim();
    final target = double.tryParse(_targetController.text.trim());
    if (name.isEmpty) {
      setState(() => _error = 'Please enter a goal name');
      return;
    }
    if (target == null || target <= 0) {
      setState(() => _error = 'Enter a valid target amount');
      return;
    }
    final navigator = Navigator.of(context);
    widget.onSave(name, target, _targetDate);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('New Savings Goal'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            autofocus: true,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(
              labelText: 'Goal name',
              hintText: 'e.g. Emergency Fund',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText: 'Target amount (RM)',
              prefixText: 'RM ',
            ),
          ),
          const SizedBox(height: 12),
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Target date (optional)',
                suffixIcon: Icon(Icons.calendar_today, size: 18),
              ),
              child: Text(
                _targetDate != null
                    ? DateFormat('dd MMM yyyy').format(_targetDate!)
                    : 'Not set',
                style: TextStyle(
                  color: _targetDate != null
                      ? AppTheme.textPrimary
                      : AppTheme.textMuted,
                ),
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 10),
            Text(
              _error!,
              style: const TextStyle(color: Color(0xFFFF6B6B), fontSize: 12),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Create')),
      ],
    );
  }
}

// ── Contribute dialog ───────────────────────────────────────────────────────

class _ContributeDialog extends StatefulWidget {
  final bool isAdd;
  final String goalName;
  final ValueChanged<double> onSubmit;

  const _ContributeDialog({
    required this.isAdd,
    required this.goalName,
    required this.onSubmit,
  });

  @override
  State<_ContributeDialog> createState() => _ContributeDialogState();
}

class _ContributeDialogState extends State<_ContributeDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final amount = double.tryParse(_controller.text.trim());
    if (amount == null || amount <= 0) {
      setState(() => _error = 'Enter a valid amount');
      return;
    }
    final navigator = Navigator.of(context);
    widget.onSubmit(amount);
    navigator.pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.isAdd ? 'Add to Goal' : 'Withdraw from Goal'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        keyboardType: const TextInputType.numberWithOptions(decimal: true),
        decoration: InputDecoration(
          labelText: 'Amount (RM)',
          prefixText: 'RM ',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _submit,
          child: Text(widget.isAdd ? 'Add' : 'Withdraw'),
        ),
      ],
    );
  }
}
