import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/models/transaction.dart' as model;
import 'package:receipto/providers/transaction_provider.dart';
import 'package:receipto/services/ocr_service.dart';
import 'package:receipto/widgets/category_chip.dart';

/// Screen that captures a receipt image, runs OCR, and lets the user
/// review/correct the parsed data before saving.
class OcrScanScreen extends StatefulWidget {
  /// The image source to open immediately on launch.
  /// Defaults to [ImageSource.camera].
  final ImageSource initialSource;

  const OcrScanScreen({
    super.key,
    this.initialSource = ImageSource.camera,
  });

  @override
  State<OcrScanScreen> createState() => _OcrScanScreenState();
}

class _OcrScanScreenState extends State<OcrScanScreen> {
  final _formKey = GlobalKey<FormState>();
  final _ocrService = OcrService();
  final _imagePicker = ImagePicker();

  final _amountController = TextEditingController();
  final _merchantController = TextEditingController();
  final _noteController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String _selectedCategory = 'Others';
  String _rawText = '';
  bool _isProcessing = false;
  bool _hasScanned = false;
  ReceiptData? _receiptData;

  @override
  void initState() {
    super.initState();
    // Launch the selected source immediately on screen open
    Future.microtask(() => _captureImage(widget.initialSource));
  }

  @override
  void dispose() {
    _amountController.dispose();
    _merchantController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  /// Captures an image from the given source and runs OCR processing.
  Future<void> _captureImage(ImageSource source) async {
    final pickedFile = await _imagePicker.pickImage(
      source: source,
      maxWidth: 1920,
      maxHeight: 1920,
      imageQuality: 90,
    );

    // User cancelled the picker
    if (pickedFile == null) {
      if (!_hasScanned && mounted) Navigator.of(context).pop();
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final receiptData = await _ocrService.processReceipt(pickedFile.path);

      setState(() {
        _receiptData = receiptData;
        _rawText = receiptData.rawText;
        _hasScanned = true;
        _isProcessing = false;

        // Pre-fill form fields with parsed values
        if (receiptData.amount != null) {
          _amountController.text = receiptData.amount!.toStringAsFixed(2);
        }
        if (receiptData.merchant != null) {
          _merchantController.text = receiptData.merchant!;
        }
        if (receiptData.date != null) {
          _selectedDate = receiptData.date!;
        }
      });
    } catch (e) {
      setState(() {
        _isProcessing = false;
        _hasScanned = true;
        _rawText = 'OCR Error: $e';
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('OCR processing failed: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan Receipt'),
        actions: [
          // Option to pick from gallery
          IconButton(
            icon: const Icon(Icons.photo_library),
            tooltip: 'Pick from Gallery',
            onPressed: () => _captureImage(ImageSource.gallery),
          ),
          // Option to retake with camera
          IconButton(
            icon: const Icon(Icons.camera_alt),
            tooltip: 'Retake Photo',
            onPressed: () => _captureImage(ImageSource.camera),
          ),
        ],
      ),
      body: _isProcessing ? _buildLoadingView() : _buildFormView(),
    );
  }

  Widget _buildLoadingView() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          CircularProgressIndicator(),
          SizedBox(height: 16),
          Text(
            'Scanning receipt...',
            style: TextStyle(fontSize: 16, color: Colors.grey),
          ),
          SizedBox(height: 8),
          Text(
            'Processing with on-device OCR',
            style: TextStyle(fontSize: 13, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildFormView() {
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Status banner
          if (_hasScanned)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.green.withAlpha(25),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.green.withAlpha(80)),
              ),
              child: const Row(
                children: [
                  Icon(Icons.check_circle, color: Colors.green, size: 20),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Receipt scanned! Review and correct the details below.',
                      style: TextStyle(color: Colors.green),
                    ),
                  ),
                ],
              ),
            ),

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
          if (_hasScanned && _receiptData != null)
            _ConfidenceBadge(_receiptData!.amountConfidence),
          const SizedBox(height: 12),

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
          if (_hasScanned && _receiptData != null)
            _ConfidenceBadge(_receiptData!.merchantConfidence),
          const SizedBox(height: 12),

          // Date picker
          InkWell(
            onTap: _pickDate,
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Date',
                suffixIcon: Icon(Icons.calendar_today),
              ),
              child: Text(
                DateFormat('dd MMM yyyy').format(_selectedDate),
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          if (_hasScanned && _receiptData != null)
            _ConfidenceBadge(_receiptData!.dateConfidence),
          const SizedBox(height: 16),

          // Category selector
          Text('Category', style: Theme.of(context).textTheme.titleSmall),
          const SizedBox(height: 8),
          Wrap(
            spacing: 0,
            runSpacing: 8,
            children: AppConstants.categories.map((cat) {
              return CategoryChip(
                category: cat,
                isSelected: _selectedCategory == cat,
                onTap: () => setState(() => _selectedCategory = cat),
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
              icon: const Icon(Icons.save),
              label: const Text('Save Transaction'),
            ),
          ),
          const SizedBox(height: 16),

          // Raw OCR text (collapsible debug section)
          if (_rawText.isNotEmpty)
            ExpansionTile(
              title: const Text('Raw OCR Text'),
              subtitle: const Text('Tap to view full scanned text'),
              leading: const Icon(Icons.text_snippet),
              children: [
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                  decoration: BoxDecoration(
                    color: Colors.grey[100],
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: SelectableText(
                    _rawText,
                    style: const TextStyle(
                      fontFamily: 'monospace',
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ),
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null) {
      setState(() => _selectedDate = picked);
    }
  }

  /// Validates the form and saves the OCR-scanned transaction.
  Future<void> _saveTransaction() async {
    if (!_formKey.currentState!.validate()) return;

    final amount = double.parse(_amountController.text.trim());
    final merchant = _merchantController.text.trim();
    final note = _noteController.text.trim();

    final transaction = model.Transaction(
      date: _selectedDate,
      merchant: merchant,
      amount: amount,
      category: _selectedCategory,
      isOcr: true,
      note: note.isNotEmpty ? note : null,
    );

    await context.read<TransactionProvider>().addTransaction(transaction);

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Transaction saved from receipt scan!'),
          backgroundColor: Colors.green,
        ),
      );
      Navigator.of(context).pop();
    }
  }
}

/// A small coloured indicator shown below each OCR-parsed form field.
///
/// - Green  (high)  — matched by a specific keyword (TOTAL, GRAND TOTAL, etc.)
/// - Orange (low)   — estimated via fallback heuristic; user should verify
/// - Red    (none)  — field could not be extracted; user must fill it in
class _ConfidenceBadge extends StatelessWidget {
  final OcrConfidence confidence;

  const _ConfidenceBadge(this.confidence);

  @override
  Widget build(BuildContext context) {
    final (IconData icon, Color color, String label) = switch (confidence) {
      OcrConfidence.high => (
          Icons.check_circle,
          Colors.green,
          'Auto-detected — looks good',
        ),
      OcrConfidence.low => (
          Icons.warning_amber,
          Colors.orange,
          'Estimated — please verify',
        ),
      OcrConfidence.none => (
          Icons.error_outline,
          Colors.red,
          'Not detected — fill in manually',
        ),
    };

    return Padding(
      padding: const EdgeInsets.only(top: 4, left: 4, bottom: 4),
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 5),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: color),
          ),
        ],
      ),
    );
  }
}
