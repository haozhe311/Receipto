import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/models/account.dart';
import 'package:receipto/models/category_model.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/providers/account_provider.dart';
import 'package:receipto/providers/category_provider.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/screens/split_screen.dart';
import 'package:receipto/services/ai_service.dart';
import 'package:receipto/services/ocr_service.dart';

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
    _type = t?.type ?? 'expense';
    _scannedViaOcr = t?.isOcr ?? false;

    // Fall back to 'Others' if the stored category was deleted.
    final knownCategories = context.read<CategoryProvider>().categoryNames;
    _selectedCategory =
        (t != null && knownCategories.contains(t.category))
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

            // Date picker
            _DatePickerTile(
              selectedDate: _selectedDate,
              onDateChanged: (date) {
                setState(() => _selectedDate = date);
              },
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
      createdAt: widget.transaction?.createdAt,
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
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
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

  /// Leading widget for a category: built-in categories keep their Material
  /// icon + colour; custom categories show their emoji (same rule as the chips).
  Widget _categoryLeading(String name) {
    final icon = AppConstants.categoryIcons[name];
    final color = AppConstants.categoryColors[name] ?? Colors.grey;
    if (icon == null) {
      final emoji = context
          .read<CategoryProvider>()
          .categories
          .where((c) => c.name == name)
          .map((c) => c.emoji)
          .firstOrNull;
      if (emoji != null && emoji.isNotEmpty) {
        return Text(emoji, style: const TextStyle(fontSize: 16, height: 1));
      }
    }
    return Icon(icon ?? Icons.more_horiz, size: 20, color: color);
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
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _CategorySheet(
        categories: context.read<CategoryProvider>().categories,
        selected: _selectedCategory,
      ),
    );
    if (picked != null && mounted) {
      setState(() => _selectedCategory = picked);
    }
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
      MaterialPageRoute(builder: (_) => const SplitScreen()),
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

/// Shared chrome for the selector bottom sheets: drag handle, title, search
/// field, and a scrollable list of option rows.
class _PickerSheet extends StatelessWidget {
  final String title;
  final TextEditingController searchController;
  final ValueChanged<String> onQueryChanged;
  final List<Widget> rows;

  const _PickerSheet({
    required this.title,
    required this.searchController,
    required this.onQueryChanged,
    required this.rows,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.75,
        ),
        child: SafeArea(
          top: false,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: AppTheme.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 10),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    title,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  controller: searchController,
                  onChanged: onQueryChanged,
                  decoration: const InputDecoration(
                    isDense: true,
                    hintText: 'Search',
                    prefixIcon: Icon(Icons.search, size: 20),
                  ),
                ),
              ),
              Flexible(
                child: rows.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 28),
                        child: Text(
                          'No matches',
                          style: TextStyle(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                          ),
                        ),
                      )
                    : ListView(shrinkWrap: true, children: rows),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

/// One selectable option row. Uniform height and easy to scan.
///
/// Supports nesting so subcategories can be added later: [depth] indents the
/// row, and when [hasChildren] is true a chevron-down/up toggle is shown that
/// calls [onToggleExpand] to reveal indented children beneath it.
class _OptionRow extends StatelessWidget {
  final String label;
  final Widget leading;
  final bool isSelected;
  final VoidCallback onSelect;

  /// Nesting support (ready for subcategories).
  final int depth;
  final bool hasChildren;
  final bool isExpanded;
  final VoidCallback? onToggleExpand;

  const _OptionRow({
    required this.label,
    required this.leading,
    required this.isSelected,
    required this.onSelect,
    this.depth = 0,
    this.hasChildren = false,
    this.isExpanded = false,
    this.onToggleExpand,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onSelect,
      child: Container(
        height: 52,
        padding: EdgeInsets.only(left: 16 + depth * 24.0, right: 8),
        child: Row(
          children: [
            SizedBox(width: 24, child: Center(child: leading)),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: isSelected ? AppTheme.gold : AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ),
            if (isSelected)
              const Icon(Icons.check, size: 18, color: AppTheme.gold),
            // Expand/collapse toggle — appears once a row has children.
            if (hasChildren)
              IconButton(
                icon: Icon(
                  isExpanded ? Icons.expand_less : Icons.expand_more,
                  size: 20,
                ),
                color: AppTheme.textMuted,
                onPressed: onToggleExpand,
              ),
          ],
        ),
      ),
    );
  }
}

/// Category picker. Rows are built through [_OptionRow] so that subcategories
/// (e.g. Groceries / Dining / Coffee under Food) render indented beneath their
/// parent as soon as [_childrenOf] returns them.
class _CategorySheet extends StatefulWidget {
  final List<CategoryModel> categories;
  final String selected;

  const _CategorySheet({required this.categories, required this.selected});

  @override
  State<_CategorySheet> createState() => _CategorySheetState();
}

class _CategorySheetState extends State<_CategorySheet> {
  final _searchController = TextEditingController();
  final Set<String> _expanded = {};
  String _query = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  /// Subcategories are not implemented yet, so every category is a leaf.
  /// When subcategory management ships, return the children here and the
  /// sheet will render them indented under their parent automatically.
  List<CategoryModel> _childrenOf(CategoryModel parent) => const [];

  Widget _leadingFor(CategoryModel c) {
    final icon = AppConstants.categoryIcons[c.name];
    final color = AppConstants.categoryColors[c.name] ?? Colors.grey;
    if (icon == null && c.emoji.isNotEmpty) {
      return Text(c.emoji, style: const TextStyle(fontSize: 16, height: 1));
    }
    return Icon(icon ?? Icons.more_horiz, size: 20, color: color);
  }

  bool _matches(CategoryModel c) =>
      c.name.toLowerCase().contains(_query.trim().toLowerCase());

  List<Widget> _buildRows() {
    final rows = <Widget>[];
    for (final cat in widget.categories) {
      final children = _childrenOf(cat);
      final matchingChildren = children.where(_matches).toList();

      // Keep a parent if it matches, or if any of its children match.
      if (!_matches(cat) && matchingChildren.isEmpty) continue;

      final isExpanded = _expanded.contains(cat.name);
      rows.add(
        _OptionRow(
          label: cat.name,
          leading: _leadingFor(cat),
          isSelected: cat.name == widget.selected,
          onSelect: () => Navigator.of(context).pop(cat.name),
          hasChildren: children.isNotEmpty,
          isExpanded: isExpanded,
          onToggleExpand: children.isEmpty
              ? null
              : () => setState(() {
                    if (isExpanded) {
                      _expanded.remove(cat.name);
                    } else {
                      _expanded.add(cat.name);
                    }
                  }),
        ),
      );

      // Children render indented beneath their parent when expanded (or when
      // a search matched them).
      final showChildren =
          isExpanded || (_query.isNotEmpty && matchingChildren.isNotEmpty);
      if (showChildren) {
        for (final child in matchingChildren.isEmpty && isExpanded
            ? children
            : matchingChildren) {
          rows.add(
            _OptionRow(
              depth: 1,
              label: child.name,
              leading: _leadingFor(child),
              isSelected: child.name == widget.selected,
              onSelect: () => Navigator.of(context).pop(child.name),
            ),
          );
        }
      }
    }
    return rows;
  }

  @override
  Widget build(BuildContext context) {
    return _PickerSheet(
      title: 'Select Category',
      searchController: _searchController,
      onQueryChanged: (v) => setState(() => _query = v),
      rows: _buildRows(),
    );
  }
}

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

  @override
  Widget build(BuildContext context) {
    final q = _query.trim().toLowerCase();
    final rows = [
      for (final a in widget.accounts)
        if (a.name.toLowerCase().contains(q))
          _OptionRow(
            label: a.name,
            leading: Icon(
              AppConstants.accountTypeIcons[a.type] ?? Icons.wallet,
              size: 20,
              color: AppTheme.gold,
            ),
            isSelected: a.name == widget.selected,
            onSelect: () => Navigator.of(context).pop(a.name),
          ),
    ];

    return _PickerSheet(
      title: 'Select Account',
      searchController: _searchController,
      onQueryChanged: (v) => setState(() => _query = v),
      rows: rows,
    );
  }
}
