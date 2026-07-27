import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/account.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/manage_categories_screen.dart';
import 'package:receipto/screens/split_screen.dart';
import 'package:receipto/services/ai_service.dart';
import 'package:receipto/services/ocr_service.dart';
import 'package:receipto/widgets/app_page_route.dart';
import 'package:receipto/widgets/category_picker_sheet.dart';
import 'package:receipto/widgets/glass.dart';

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
  late TimeOfDay _selectedTime;
  late String _selectedCategory;
  late String _selectedPaymentMethod;
  late String _type; // 'expense' or 'income'

  final _ocrService = OcrService();
  final _imagePicker = ImagePicker();
  bool _isScanning = false;
  late bool _scannedViaOcr;

  bool get _isEditing => widget.transaction != null;
  bool get _isIncome => _type == 'income';

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
    // Time of day lives in createdAt (the date column is date-only). Default to
    // the record's timestamp, or now for a new transaction.
    _selectedTime = TimeOfDay.fromDateTime(t?.createdAt ?? DateTime.now());
    _type = t?.type ?? 'expense';
    _scannedViaOcr = t?.isOcr ?? false;

    // Keep the stored value if it's still a valid category OR subcategory;
    // otherwise fall back to 'Others'.
    final categoryProvider = context.read<CategoryProvider>();
    _selectedCategory = (t != null && categoryProvider.isSelectable(t.category))
        ? t.category
        : 'Others';

    // Payment method now maps to an account. Fall back to the first account
    // (or 'Cash') if the stored one no longer exists.
    final accountNames = context.read<AccountProvider>().accountNames;
    _selectedPaymentMethod =
        (t != null && accountNames.contains(t.paymentMethod))
            ? t.paymentMethod
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
        title: Text(_isEditing ? 'Edit Transaction' : 'Add Transaction'),
        actions: [
          if (!_isIncome)
            IconButton(
              icon: const Icon(Icons.document_scanner),
              tooltip: 'Scan Receipt',
              onPressed: _isScanning ? null : _showScanSourceSheet,
            ),
          if (!_isIncome)
            IconButton(
              icon: const Icon(Icons.call_split),
              tooltip: 'Split by Items',
              onPressed: _openSplit,
            ),
          if (_isEditing)
            IconButton(
              icon: const Icon(Icons.delete),
              tooltip: 'Delete',
              onPressed: _confirmDelete,
            ),
        ],
      ),
      body: Stack(
        children: [
          Form(
            key: _formKey,
            child: ListView(
              padding: const EdgeInsets.all(16),
              children: [
            // Expense / Income toggle
            SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'expense',
                  label: Text('Expense'),
                  icon: Icon(Icons.arrow_upward),
                ),
                ButtonSegment(
                  value: 'income',
                  label: Text('Income'),
                  icon: Icon(Icons.arrow_downward),
                ),
              ],
              selected: {_type},
              onSelectionChanged: (selected) {
                setState(() => _type = selected.first);
              },
            ),
            const SizedBox(height: 20),

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

            // Merchant / source field (label depends on type)
            TextFormField(
              controller: _merchantController,
              decoration: InputDecoration(
                labelText: _isIncome ? 'Source' : 'Merchant',
                hintText: _isIncome
                    ? 'e.g. Salary, Freelance, Allowance'
                    : 'e.g. KFC, Grab, Uniqlo',
              ),
              textCapitalization: TextCapitalization.words,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return _isIncome
                      ? 'Please enter an income source'
                      : 'Please enter a merchant name';
                }
                return null;
              },
            ),
            const SizedBox(height: 16),

            // Date + time pickers, side by side.
            Row(
              children: [
                Expanded(
                  child: _DatePickerTile(
                    selectedDate: _selectedDate,
                    onDateChanged: (date) {
                      setState(() => _selectedDate = date);
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _TimePickerTile(
                    selectedTime: _selectedTime,
                    onTimeChanged: (time) {
                      setState(() => _selectedTime = time);
                    },
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            // Category selector row → bottom sheet
            _SelectorTile(
              label: 'Category',
              value: _selectedCategory,
              leading: _categoryLeading(_selectedCategory),
              onTap: _openCategorySheet,
            ),
            const SizedBox(height: 16),

            // Account selector row → bottom sheet
            // (accounts double as payment methods)
            _SelectorTile(
              label: 'Account',
              value: _selectedPaymentMethod,
              leading: _accountLeading(_selectedPaymentMethod),
              onTap: _openAccountSheet,
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
                label: Text(
                  _isEditing ? 'Update Transaction' : 'Add Transaction',
                ),
              ),
            ),
              ],
            ),
          ),
          if (_isScanning)
            const Positioned.fill(
              child: ColoredBox(
                color: Color(0x99000000),
                child: Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  /// Validates the form and saves the transaction to the database.
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) { return; }

    final amount = double.parse(_amountController.text.trim());
    final merchant = _merchantController.text.trim();
    final note = _noteController.text.trim();

    // The chosen date + time. The date column stays date-only (for month/range
    // filters); the full timestamp — carrying the time — is stored in createdAt.
    final dateTime = DateTime(
      _selectedDate.year,
      _selectedDate.month,
      _selectedDate.day,
      _selectedTime.hour,
      _selectedTime.minute,
    );

    final transaction = model.Transaction(
      id: widget.transaction?.id,
      date: _selectedDate,
      merchant: merchant,
      amount: amount,
      category: _selectedCategory,
      paymentMethod: _selectedPaymentMethod,
      type: _type,
      isOcr: _scannedViaOcr,
      note: note.isNotEmpty ? note : null,
      createdAt: dateTime,
    );

    final provider = context.read<TransactionProvider>();

    if (_isEditing) {
      await provider.updateTransaction(transaction);
    } else {
      await provider.addTransaction(transaction);
    }

    // Refresh account balances / net worth to reflect this transaction.
    if (mounted) { context.read<AccountProvider>().loadAccounts(); }

    if (mounted) { Navigator.of(context).pop(); }
  }

  // ── Receipt scanning ────────────────────────────────────────────────────────

  /// Bottom sheet to choose camera or gallery, then run OCR.
  void _showScanSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      barrierColor: Colors.black.withValues(alpha: 0.2),
      builder: (ctx) => FrostedSheetBackground(
        child: SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(top: 12),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text(
                'Scan Receipt',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
              title: const Text('Take Photo'),
              subtitle: const Text('Open the device camera'),
              onTap: () {
                Navigator.of(ctx).pop();
                _scanReceipt(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.photo_library)),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick an existing photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _scanReceipt(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
          ),
        ),
      ),
    );
  }

  /// Captures/picks an image, runs OCR, and fills the form fields. When an AI
  /// key is configured, the OCR text is parsed by the LLM (much more accurate
  /// across layouts); otherwise it falls back to the on-device regex parser.
  Future<void> _scanReceipt(ImageSource source) async {
    // Read AI settings before any await gap.
    final settings = context.read<SettingsProvider>();
    final apiKey = settings.hasApiKey ? settings.apiKey : null;
    final aiProvider = settings.aiProvider;
    final groqModel = settings.groqModel;

    // Valid category values the receipt can be classified into: each category's
    // subcategory names, or the category name itself when it has none.
    final categoryProvider = context.read<CategoryProvider>();
    final categoryOptions = <String>[
      for (final c in categoryProvider.categories)
        if (c.subcategories.isEmpty)
          c.name
        else
          ...c.subcategories.map((s) => s.name),
    ];

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (picked == null) return;

    setState(() => _isScanning = true);
    try {
      final rawText = await _ocrService.recognizeText(picked.path);
      ReceiptData data = _ocrService.parseReceipt(rawText);
      var usedAi = false;
      if (apiKey != null) {
        final ai = await AiService.parseReceipt(
          rawText: rawText,
          apiKey: apiKey,
          provider: aiProvider,
          groqModel: groqModel,
          categoryOptions: categoryOptions,
        );
        if (ai != null) {
          data = ai;
          usedAi = true;
        }
      }
      if (!mounted) return;
      setState(() {
        if (data.amount != null) {
          _amountController.text = data.amount!.toStringAsFixed(2);
        }
        if (data.merchant != null && data.merchant!.isNotEmpty) {
          _merchantController.text = data.merchant!;
        }
        if (data.date != null) _selectedDate = data.date!;
        // Auto-select the classified category/subcategory when it's a valid,
        // selectable value.
        if (data.category != null &&
            categoryProvider.isSelectable(data.category!)) {
          _selectedCategory = data.category!;
        }
        _scannedViaOcr = true;
        _isScanning = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(usedAi
              ? 'Receipt read by AI — review and correct the details.'
              : 'Receipt scanned — review and correct the details.'),
          backgroundColor: const Color(0xFF2E7D32),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isScanning = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Could not read the receipt: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  // ── Category / Account selectors ────────────────────────────────────────────

  /// Leading widget for the selected category value. Top-level categories use
  /// their own swatch (or legacy emoji); a subcategory inherits its parent's
  /// icon so the row still shows a meaningful icon.
  Widget _categoryLeading(String value) {
    final provider = context.read<CategoryProvider>();
    final cat = provider.byName(value);
    if (cat != null) {
      return categoryIconWidget(
          value, cat.iconKey, cat.emoji, 20, cat.colorValue);
    }
    // A subcategory value: show its own glyph tinted with the parent's colour.
    final parentName = provider.parentOf(value);
    if (parentName != null) {
      final parent = provider.byName(parentName);
      final sub = provider.subcategoryOf(value);
      final color = CategoryGlyphs.categoryVisual(
        name: parentName,
        iconKey: parent?.iconKey,
        colorValue: parent?.colorValue,
      ).color;
      return CategoryGlyph(
        assetPath: CategoryGlyphs.subcategoryAssetFor(sub?.iconKey),
        color: color,
        size: 20,
      );
    }
    return categoryIconWidget(value, null, '');
  }

  /// Leading widget for an account, based on its type.
  Widget _accountLeading(String name) {
    final type = context
            .read<AccountProvider>()
            .accounts
            .where((a) => a.name == name)
            .map((a) => a.type)
            .firstOrNull ??
        'other';
    return Icon(
      AppConstants.accountTypeIcons[type] ?? Icons.wallet,
      size: 20,
      color: AppTheme.gold,
    );
  }

  Future<void> _openCategorySheet() async {
    final result = await showModalBottomSheet<CategoryPick>(
      context: context,
      isScrollControlled: true,
      builder: (_) => CategorySheet(
        categories: context.read<CategoryProvider>().categories,
        selected: _selectedCategory,
      ),
    );
    if (result == null || !mounted) return;
    if (result is CategoryPickValue) {
      setState(() => _selectedCategory = result.value);
    } else if (result is CategoryPickManage) {
      _openManageCategories();
    }
  }

  /// Opens Manage Categories on the root navigator, above this Add Transaction
  /// screen. Because Add Transaction is only covered (not popped/disposed), all
  /// its entered fields are preserved, and pressing back returns here.
  void _openManageCategories() {
    Navigator.of(context).push(
      AppPageRoute(builder: (_) => const ManageCategoriesScreen()),
    );
  }

  Future<void> _openAccountSheet() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _AccountSheet(
        accounts: context.read<AccountProvider>().accounts,
        selected: _selectedPaymentMethod,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedPaymentMethod = picked);
    }
  }

  // ── Split by items ──────────────────────────────────────────────────────────

  /// Opens the itemised bill splitter; on return, fills the amount with the
  /// user's computed share (and merchant/date if the receipt was scanned there).
  Future<void> _openSplit() async {
    final result = await Navigator.push<SplitResult>(
      context,
      AppPageRoute(builder: (_) => const SplitScreen()),
    );
    if (result == null || !mounted) return;
    setState(() {
      if (result.share > 0) {
        _amountController.text = result.share.toStringAsFixed(2);
      }
      if (result.merchant != null && result.merchant!.isNotEmpty) {
        _merchantController.text = result.merchant!;
      }
      if (result.date != null) _selectedDate = result.date!;
      _type = 'expense';
    });
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
              final accounts = context.read<AccountProvider>();
              Navigator.of(ctx).pop();
              await context
                  .read<TransactionProvider>()
                  .deleteTransaction(widget.transaction!.id!);
              accounts.loadAccounts(); // refresh net worth
              if (mounted) { Navigator.of(context).pop(); }
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
        if (picked != null) { onDateChanged(picked); }
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

class _TimePickerTile extends StatelessWidget {
  final TimeOfDay selectedTime;
  final ValueChanged<TimeOfDay> onTimeChanged;

  const _TimePickerTile({
    required this.selectedTime,
    required this.onTimeChanged,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: () async {
        final picked = await showTimePicker(
          context: context,
          initialTime: selectedTime,
        );
        if (picked != null) onTimeChanged(picked);
      },
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: const InputDecoration(
          labelText: 'Time',
          suffixIcon: Icon(Icons.access_time),
        ),
        child: Text(
          selectedTime.format(context),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
}

// ── Selector row ──────────────────────────────────────────────────────────────

/// A single-line selector row styled like [_DatePickerTile]: floating label,
/// a leading icon, the selected value, and a trailing chevron. Tapping opens
/// a picker sheet.
class _SelectorTile extends StatelessWidget {
  final String label;
  final String value;
  final Widget leading;
  final VoidCallback onTap;

  const _SelectorTile({
    required this.label,
    required this.value,
    required this.leading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: SizedBox(width: 46, child: Center(child: leading)),
          suffixIcon: const Icon(Icons.chevron_right),
        ),
        child: Text(value, style: Theme.of(context).textTheme.bodyLarge),
      ),
    );
  }
}

// ── Picker sheets ─────────────────────────────────────────────────────────────

/// Account picker.
class _AccountSheet extends StatefulWidget {
  final List<Account> accounts;
  final String selected;

  const _AccountSheet({required this.accounts, required this.selected});

  @override
  State<_AccountSheet> createState() => _AccountSheetState();
}

class _AccountSheetState extends State<_AccountSheet> {
  final _searchController = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Lightweight name-only account creation from the picker header: prompt for
  /// a name, create the account with a guessed type (opening balance 0), then
  /// select it and close the sheet. Mirrors the quick-add flow used elsewhere —
  /// full account setup still lives on the Wallets screen.
  Future<void> _quickAddAccount() async {
    final name = await showDialog<String>(
      context: context,
      builder: (_) => const _QuickAddAccountDialog(),
    );
    if (name == null || !mounted) return;
    final trimmed = name.trim();
    if (trimmed.isEmpty) return;

    final provider = context.read<AccountProvider>();
    // Reuse an existing account with the same name rather than duplicating it.
    final exists = provider.accountNames
        .any((n) => n.toLowerCase() == trimmed.toLowerCase());
    if (!exists) {
      await provider.addAccount(
        name: trimmed,
        type: AccountProvider.guessType(trimmed),
        openingBalance: 0,
      );
    }
    if (mounted) Navigator.of(context).pop(trimmed);
  }

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final specs = <RowSpec>[
      for (final a in widget.accounts)
        if (a.name.toLowerCase().contains(q))
          RowSpec(
            label: a.name,
            leading: Icon(
              AppConstants.accountTypeIcons[a.type] ?? Icons.wallet,
              size: kCatIconSize,
              color: AppTheme.gold,
            ),
            isSelected: a.name == widget.selected,
            onSelect: () => Navigator.of(context).pop(a.name),
          ),
    ];

    return PickerSheet(
      title: 'Select Account',
      fillHeight: true,
      searchController: _searchController,
      onQueryChanged: (v) => setState(() => _query = v),
      rows: pickerRows(specs),
      action: IconButton(
        icon: const Icon(Icons.add, size: 22),
        tooltip: 'Add account',
        color: AppTheme.gold,
        onPressed: _quickAddAccount,
      ),
    );
  }
}

/// Simple name-only dialog for quick-adding an account from the picker sheet.
/// Returns the entered name (or null on cancel).
class _QuickAddAccountDialog extends StatefulWidget {
  const _QuickAddAccountDialog();

  @override
  State<_QuickAddAccountDialog> createState() => _QuickAddAccountDialogState();
}

class _QuickAddAccountDialogState extends State<_QuickAddAccountDialog> {
  final _controller = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _save() {
    final value = _controller.text.trim();
    if (value.isEmpty) {
      setState(() => _error = 'Enter an account name');
      return;
    }
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Add Account'),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textCapitalization: TextCapitalization.words,
        decoration: InputDecoration(
          labelText: 'Account name',
          hintText: 'e.g. Cash, Maybank, TNG',
          errorText: _error,
        ),
        onChanged: (_) {
          if (_error != null) setState(() => _error = null);
        },
        onSubmitted: (_) => _save(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(onPressed: _save, child: const Text('Add')),
      ],
    );
  }
}
