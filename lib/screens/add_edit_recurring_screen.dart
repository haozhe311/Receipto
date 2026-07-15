import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/recurring_transaction.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/recurring_provider.dart';
import 'package:receipto/widgets/category_chip.dart';
import 'package:receipto/widgets/payment_method_chip.dart';

/// Full-screen form for creating or editing a recurring transaction.
/// Used by both the Recurring and Subscriptions screens.
class AddEditRecurringScreen extends StatefulWidget {
  final RecurringTransaction? existing;
  final bool defaultSubscription;

  const AddEditRecurringScreen({
    super.key,
    this.existing,
    this.defaultSubscription = false,
  });

  @override
  State<AddEditRecurringScreen> createState() => _AddEditRecurringScreenState();
}

class _AddEditRecurringScreenState extends State<AddEditRecurringScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  late DateTime _nextDate;
  late String _category;
  late String _paymentMethod;
  late String _type;
  late String _frequency;
  late bool _isSubscription;

  bool get _isEditing => widget.existing != null;
  bool get _isIncome => _type == 'income';

  @override
  void initState() {
    super.initState();
    final r = widget.existing;
    _amountController = TextEditingController(
      text: r != null ? r.amount.toStringAsFixed(2) : '',
    );
    _merchantController = TextEditingController(text: r?.merchant ?? '');
    _noteController = TextEditingController(text: r?.note ?? '');
    _nextDate = r?.nextDate ?? DateTime.now().add(const Duration(days: 1));
    _type = r?.type ?? 'expense';
    _frequency = r?.frequency ?? 'monthly';
    _isSubscription = r?.isSubscription ?? widget.defaultSubscription;

    final knownCats = context.read<CategoryProvider>().categoryNames;
    _category = (r != null && knownCats.contains(r.category))
        ? r.category
        : (knownCats.isNotEmpty ? knownCats.first : 'Others');

    final accountNames = context.read<AccountProvider>().accountNames;
    _paymentMethod = (r != null && accountNames.contains(r.paymentMethod))
        ? r.paymentMethod
        : (accountNames.isNotEmpty ? accountNames.first : 'Cash');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Recurring' : 'New Recurring'),
        actions: [
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'expense', label: Text('Expense')),
                ButtonSegment(value: 'income', label: Text('Income')),
              ],
              selected: {_type},
              onSelectionChanged: (s) => setState(() => _type = s.first),
            ),
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (RM)',
                prefixText: 'RM ',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (v) {
                final parsed = double.tryParse((v ?? '').trim());
                if (parsed == null || parsed <= 0) {
                  return 'Enter a valid amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: _isIncome ? 'Source' : 'Merchant',
                hintText: _isIncome ? 'e.g. Salary' : 'e.g. Netflix, Rent',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Required' : null,
            ),
            const SizedBox(height: 16),

            // Frequency
            Text('Frequency', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(value: 'weekly', label: Text('Weekly')),
                ButtonSegment(value: 'monthly', label: Text('Monthly')),
              ],
              selected: {_frequency},
              onSelectionChanged: (s) => setState(() => _frequency = s.first),
            ),
            const SizedBox(height: 16),

            // Next date
            _DateTile(
              label: 'Next date',
              date: _nextDate,
              onChanged: (d) => setState(() => _nextDate = d),
            ),
            const SizedBox(height: 16),

            // Category
            Text('Category', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 8,
              children: context.watch<CategoryProvider>().categories.map((c) {
                return CategoryChip(
                  category: c.name,
                  iconKey: c.iconKey,
                  emoji: c.emoji,
                  isSelected: _category == c.name,
                  onTap: () => setState(() => _category = c.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Account (accounts double as payment methods)
            Text('Account',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              runSpacing: 8,
              children:
                  context.watch<AccountProvider>().accounts.map((a) {
                return PaymentMethodChip(
                  method: a.name,
                  isSelected: _paymentMethod == a.name,
                  onTap: () => setState(() => _paymentMethod = a.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Subscription toggle
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: AppTheme.border),
              ),
              child: SwitchListTile(
                value: _isSubscription,
                onChanged: (v) => setState(() => _isSubscription = v),
                activeColor: AppTheme.gold,
                title: const Text('Track as subscription'),
                subtitle: Text(
                  'Show in the Subscriptions screen',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
                ),
              ),
            ),
            const SizedBox(height: 16),

            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 24),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _save,
                icon: Icon(_isEditing ? Icons.check : Icons.add),
                label: Text(_isEditing ? 'Save Changes' : 'Create'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    final note = _noteController.text.trim();

    final recurring = RecurringTransaction(
      id: widget.existing?.id,
      merchant: _merchantController.text.trim(),
      amount: double.parse(_amountController.text.trim()),
      category: _category,
      paymentMethod: _paymentMethod,
      type: _type,
      frequency: _frequency,
      nextDate: _nextDate,
      isSubscription: _isSubscription,
      note: note.isNotEmpty ? note : null,
      active: widget.existing?.active ?? true,
      createdAt: widget.existing?.createdAt,
    );

    final provider = context.read<RecurringProvider>();
    if (_isEditing) {
      await provider.updateRecurring(recurring);
    } else {
      await provider.addRecurring(recurring);
    }
    if (mounted) Navigator.of(context).pop();
  }

  void _confirmDelete() {
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Recurring'),
        content: Text(
          'Delete "${widget.existing!.merchant}"? '
          'Already-posted transactions are kept.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              final navigator = Navigator.of(context);
              Navigator.of(ctx).pop();
              await context
                  .read<RecurringProvider>()
                  .deleteRecurring(widget.existing!.id!);
              navigator.pop();
            },
            style: TextButton.styleFrom(foregroundColor: const Color(0xFFFF6B6B)),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

class _DateTile extends StatelessWidget {
  final String label;
  final DateTime date;
  final ValueChanged<DateTime> onChanged;

  const _DateTile({
    required this.label,
    required this.date,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date,
          firstDate: DateTime(2020),
          lastDate: DateTime(DateTime.now().year + 10),
        );
        if (picked != null) onChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          suffixIcon: const Icon(Icons.calendar_today, size: 18),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(date),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
