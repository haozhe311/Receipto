import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/widgets/category_chip.dart';

/// Screen for manually adding a new transaction or editing an existing one.
///
/// When [transaction] is provided, the form pre-fills with its values and
/// operates in edit mode (showing a delete button in the AppBar).
class AddEditTransactionScreen extends StatefulWidget {
  final model.Transaction? transaction;

  const AddEditTransactionScreen({super.key, this.transaction});

  @override
  State<AddEditTransactionScreen> createState() =>
      _AddEditTransactionScreenState();
}

class _AddEditTransactionScreenState extends State<AddEditTransactionScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _amountController;
  late final TextEditingController _merchantController;
  late final TextEditingController _noteController;
  late DateTime _selectedDate;
  late String _selectedCategory;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final t = widget.transaction;
    _amountController = TextEditingController(
      text: t != null ? t.amount.toStringAsFixed(2) : '',
    );
    _merchantController = TextEditingController(text: t?.merchant ?? '');
    _noteController = TextEditingController(text: t?.note ?? '');
    _selectedDate = t?.date ?? DateTime.now();
    // Fall back to 'Others' if the stored category was deleted.
    final knownCategories =
        context.read<CategoryProvider>().categoryNames;
    _selectedCategory =
        (t != null && knownCategories.contains(t.category))
            ? t.category
            : 'Others';
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
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
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
            // Amount field
            TextFormField(
              controller: _amountController,
              decoration: const InputDecoration(
                labelText: 'Amount (RM)',
                prefixText: 'RM ',
                hintText: '0.00',
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter an amount';
                }
                final parsed = double.tryParse(value.trim());
                if (parsed == null || parsed <= 0) {
                  return 'Please enter a valid positive amount';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Merchant field
            TextFormField(
              controller: _merchantController,
              decoration: const InputDecoration(
                labelText: 'Merchant',
                hintText: 'e.g. KFC, Grab, Uniqlo',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a merchant name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date picker
            _DatePickerTile(
              selectedDate: _selectedDate,
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
              },
            ),
            const SizedBox(height: 16),

            // Category selector
            Text(
              'Category',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 0,
              runSpacing: 8,
              children: context.watch<CategoryProvider>().categories.map((cat) {
                return CategoryChip(
                  category: cat.name,
                  emoji: cat.emoji,
                  isSelected: _selectedCategory == cat.name,
                  onTap: () => setState(() => _selectedCategory = cat.name),
                );
              }).toList(),
            ),
            const SizedBox(height: 16),

            // Note field (optional)
            TextFormField(
              controller: _noteController,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                hintText: 'Any additional details...',
              ),
              maxLines: 3,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 24),

            // Save button
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _saveTransaction,
                icon: Icon(_isEditing ? Icons.check : Icons.add),
                label: Text(_isEditing ? 'Update Transaction' : 'Add Transaction'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Validates the form and saves the transaction to the database.
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final merchant = _merchantController.text.trim();
    final note = _noteController.text.trim();

    final transaction = model.Transaction(
      id: widget.transaction?.id,
      date: _selectedDate,
      merchant: merchant,
      amount: amount,
      category: _selectedCategory,
      isOcr: widget.transaction?.isOcr ?? false,
      note: note.isNotEmpty ? note : null,
      createdAt: widget.transaction?.createdAt,
    );

    final provider = context.read<TransactionProvider>();

    if (_isEditing) {
      await provider.updateTransaction(transaction);
    } else {
      await provider.addTransaction(transaction);
    }

    if (mounted) Navigator.of(context).pop();
  }

  /// Shows a confirmation dialog before deleting the transaction.
  void _confirmDelete() {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete Transaction'),
        content: Text(
          'Are you sure you want to delete "${widget.transaction!.merchant}"?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await context
                  .read<TransactionProvider>()
                  .deleteTransaction(widget.transaction!.id!);
              if (mounted) Navigator.of(context).pop();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}

/// A tappable row that shows the selected date and opens a date picker.
class _DatePickerTile extends StatelessWidget {
  final DateTime selectedDate;
  final ValueChanged<DateTime> onDateChanged;

  const _DatePickerTile({
    required this.selectedDate,
    required this.onDateChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: selectedDate,
          firstDate: DateTime(2020),
          lastDate: DateTime.now(),
        );
        if (picked != null) onDateChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Date',
          suffixIcon: Icon(Icons.calendar_today),
        ),
        child: Text(
          DateFormat('dd MMM yyyy').format(selectedDate),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}
