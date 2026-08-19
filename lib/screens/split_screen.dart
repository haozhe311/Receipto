import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';
import 'package:receipto/providers/settings_provider.dart';
import 'package:receipto/services/ai_service.dart';

/// Returned to the caller when the user confirms their share.
class SplitResult {
  final double share;
  final String? merchant;
  final DateTime? date;

  const SplitResult({required this.share, this.merchant, this.date});
}

/// Itemised bill splitter.
///
/// Scan a receipt → its items are listed → set how many of each you had →
/// the app adds the service charge and SST percentages to your items to give
/// your share. Working from the printed percentages keeps the maths stable
/// and transparent regardless of how well the scan read the quantities.
class SplitScreen extends StatefulWidget {
  const SplitScreen({super.key});

  @override
  State<SplitScreen> createState() => _SplitScreenState();
}

/// An editable item row: name, unit price, and how many YOU had.
class _ItemRow {
  final TextEditingController name;
  final TextEditingController price;
  int qty;

  _ItemRow({String name = '', String price = ''})
      : name = TextEditingController(text: name),
        price = TextEditingController(text: price),
        qty = 0;

  double get unitPrice => double.tryParse(price.text.trim()) ?? 0;
  double get myTotal => unitPrice * qty;

  void dispose() {
    name.dispose();
    price.dispose();
  }
}

class _SplitScreenState extends State<SplitScreen> {
  final _imagePicker = ImagePicker();
  final _serviceController = TextEditingController(text: '10');
  final _sstController = TextEditingController(text: '6');

  final List<_ItemRow> _items = [];
  String? _merchant;
  DateTime? _date;
  bool _isScanning = false;
  bool _hasContent = false;

  final _fmt = NumberFormat.currency(
    locale: AppConstants.currencyLocale,
    symbol: AppConstants.currencySymbol,
  );

  @override
  void dispose() {
    _serviceController.dispose();
    _sstController.dispose();
    for (final i in _items) {
      i.dispose();
    }
    super.dispose();
  }

  // ── Derived amounts ─────────────────────────────────────────────────────────

  /// Your items at their unit prices (before fees).
  double get _mySubtotal =>
      _items.fold(0.0, (sum, i) => sum + i.myTotal);

  double get _servicePct => double.tryParse(_serviceController.text.trim()) ?? 0;
  double get _sstPct => double.tryParse(_sstController.text.trim()) ?? 0;

  double get _serviceAmount => _mySubtotal * _servicePct / 100;
  double get _sstAmount => _mySubtotal * _sstPct / 100;
  double get _myShare => _mySubtotal + _serviceAmount + _sstAmount;

  // ── Actions ─────────────────────────────────────────────────────────────────

  void _showScanSourceSheet() {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 16, 16, 8),
              child: Text('Scan Receipt',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.camera_alt)),
              title: const Text('Take Photo'),
              onTap: () {
                Navigator.of(ctx).pop();
                _scan(ImageSource.camera);
              },
            ),
            ListTile(
              leading: const CircleAvatar(child: Icon(Icons.photo_library)),
              title: const Text('Choose from Gallery'),
              onTap: () {
                Navigator.of(ctx).pop();
                _scan(ImageSource.gallery);
              },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Future<void> _scan(ImageSource source) async {
    // Scanning always uses Groq's vision model, independent of the currently
    // selected chat provider.
    final settings = context.read<SettingsProvider>();
    final groqApiKey = settings.activeKeyFor('groq');

    final picked = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );
    if (picked == null) return;

    if (groqApiKey == null || groqApiKey.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Add a Groq API key in Settings to scan receipts.'),
          backgroundColor: Colors.red,
        ),
      );
      return;
    }

    setState(() => _isScanning = true);
    try {
      final imageBytes = await picked.readAsBytes();
      final data = await AiService.parseReceiptFromImage(
        imageBytes: imageBytes,
        apiKey: groqApiKey,
      );
      if (data == null) {
        throw AiException(
          'The image could not be read. Try a clearer photo.',
        );
      }
      if (!mounted) return;
      setState(() {
        for (final i in _items) {
          i.dispose();
        }
        _items
          ..clear()
          ..addAll(data.items.map((it) => _ItemRow(
                name: it.name,
                price: it.price.toStringAsFixed(2),
              )));
        if (_items.isEmpty) _items.add(_ItemRow());
        // Use detected rates when available; otherwise keep common defaults.
        if (data.serviceRate != null) {
          _serviceController.text = _trimRate(data.serviceRate!);
        }
        if (data.taxRate != null) {
          _sstController.text = _trimRate(data.taxRate!);
        }
        _merchant = data.merchant;
        _date = data.date;
        _hasContent = true;
        _isScanning = false;
      });
      if (data.items.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              "Couldn't read individual items — add them manually below.",
            ),
          ),
        );
      }
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

  String _trimRate(double v) =>
      v == v.roundToDouble() ? v.toStringAsFixed(0) : v.toString();

  void _startManual() {
    setState(() {
      _items.add(_ItemRow());
      _hasContent = true;
    });
  }

  void _addItem() => setState(() => _items.add(_ItemRow()));

  void _removeItem(int index) {
    setState(() {
      _items[index].dispose();
      _items.removeAt(index);
    });
  }

  void _confirm() {
    Navigator.of(context).pop(
      SplitResult(share: _myShare, merchant: _merchant, date: _date),
    );
  }

  // ── UI ──────────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Split by Items'),
        actions: [
          if (_hasContent)
            IconButton(
              icon: const Icon(Icons.document_scanner),
              tooltip: 'Rescan',
              onPressed: _isScanning ? null : _showScanSourceSheet,
            ),
        ],
      ),
      body: Stack(
        children: [
          if (!_hasContent) _intro() else _editor(),
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

  Widget _intro() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.receipt_long, size: 60, color: AppTheme.textMuted),
            const SizedBox(height: 16),
            Text(
              'Split a bill by items',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 17,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Scan the receipt, set how many of each item you had, and your '
              'share — including service charge and SST — is worked out for you.',
              textAlign: TextAlign.center,
              style: TextStyle(color: AppTheme.textMuted, fontSize: 13),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton.icon(
                onPressed: _showScanSourceSheet,
                icon: const Icon(Icons.document_scanner),
                label: const Text('Scan Receipt'),
              ),
            ),
            const SizedBox(height: 10),
            TextButton(
              onPressed: _startManual,
              child: const Text('Or add items manually'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _editor() {
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
      children: [
        if (_merchant != null) ...[
          Text(
            _merchant!,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 4),
        ],
        Text(
          'Set how many of each item you had.',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 12),
        ),
        const SizedBox(height: 12),

        for (int i = 0; i < _items.length; i++) _itemCard(i),

        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: _addItem,
            icon: const Icon(Icons.add, size: 18),
            label: const Text('Add item'),
          ),
        ),
        const SizedBox(height: 12),

        // Fee percentages — from the receipt, editable.
        Text(
          'CHARGES (from the receipt)',
          style: TextStyle(
            color: AppTheme.gold,
            fontSize: 11,
            fontWeight: FontWeight.w700,
            letterSpacing: 1,
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _serviceController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'Service charge',
                  suffixText: '%',
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: TextField(
                controller: _sstController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => setState(() {}),
                decoration: const InputDecoration(
                  labelText: 'SST / tax',
                  suffixText: '%',
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 20),

        _summary(),
        const SizedBox(height: 20),

        SizedBox(
          width: double.infinity,
          child: ElevatedButton.icon(
            onPressed: _myShare > 0 ? _confirm : null,
            icon: const Icon(Icons.check),
            label: Text('Use my share  ·  ${_fmt.format(_myShare)}'),
          ),
        ),
      ],
    );
  }

  Widget _itemCard(int index) {
    final item = _items[index];
    final mine = item.qty > 0;
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: mine ? AppTheme.goldDark : AppTheme.surfaceHigh,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: mine ? AppTheme.gold.withAlpha(120) : AppTheme.border,
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: item.name,
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Item',
                  ),
                ),
              ),
              IconButton(
                onPressed: () => _removeItem(index),
                icon: const Icon(Icons.remove_circle_outline, size: 20),
                color: const Color(0xFFFF6B6B),
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              SizedBox(
                width: 120,
                child: TextField(
                  controller: item.price,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => setState(() {}),
                  decoration: const InputDecoration(
                    isDense: true,
                    labelText: 'Unit price',
                    prefixText: 'RM ',
                  ),
                ),
              ),
              const Spacer(),
              Text('You had',
                  style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              IconButton(
                onPressed:
                    item.qty > 0 ? () => setState(() => item.qty--) : null,
                icon: const Icon(Icons.remove_circle_outline),
                color: AppTheme.gold,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
              ),
              SizedBox(
                width: 22,
                child: Text(
                  '${item.qty}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              IconButton(
                onPressed: () => setState(() => item.qty++),
                icon: const Icon(Icons.add_circle_outline),
                color: AppTheme.gold,
                visualDensity: VisualDensity.compact,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                constraints: const BoxConstraints(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _summary() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.glassRowFill,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.glassBorderSoft),
      ),
      child: Column(
        children: [
          _summaryRow('My items', _mySubtotal),
          const SizedBox(height: 8),
          _summaryRow(
            'Service charge (${_trimRate(_servicePct)}%)',
            _serviceAmount,
          ),
          const SizedBox(height: 8),
          _summaryRow('SST (${_trimRate(_sstPct)}%)', _sstAmount),
          const Divider(height: 20),
          _summaryRow('My share', _myShare, emphasise: true),
        ],
      ),
    );
  }

  Widget _summaryRow(String label, double value, {bool emphasise = false}) {
    return Row(
      children: [
        Text(
          label,
          style: TextStyle(
            color: emphasise ? AppTheme.textPrimary : AppTheme.textMuted,
            fontSize: emphasise ? 15 : 13,
            fontWeight: emphasise ? FontWeight.w600 : FontWeight.w400,
          ),
        ),
        const Spacer(),
        Text(
          _fmt.format(value),
          style: TextStyle(
            color: emphasise ? AppTheme.gold : AppTheme.textPrimary,
            fontSize: emphasise ? 18 : 14,
            fontWeight: emphasise ? FontWeight.bold : FontWeight.w500,
          ),
        ),
      ],
    );
  }
}
