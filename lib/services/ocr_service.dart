import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Confidence level for each parsed receipt field.
enum OcrConfidence {
  /// Matched using a high-confidence keyword (e.g. TOTAL, GRAND TOTAL).
  high,

  /// Matched using a fallback heuristic (e.g. largest value, first line).
  low,

  /// Field could not be extracted from the receipt text.
  none,
}

/// Holds the parsed data and per-field confidence extracted from a receipt.
class ReceiptData {
  final String? merchant;
  final double? amount;
  final DateTime? date;

  /// Original, unmodified OCR output shown in the debug section.
  final String rawText;

  final OcrConfidence merchantConfidence;
  final OcrConfidence amountConfidence;
  final OcrConfidence dateConfidence;

  ReceiptData({
    this.merchant,
    this.amount,
    this.date,
    required this.rawText,
    this.merchantConfidence = OcrConfidence.none,
    this.amountConfidence = OcrConfidence.none,
    this.dateConfidence = OcrConfidence.none,
  });
}

/// Handles on-device OCR using Google ML Kit Text Recognition v2
/// and parses the raw text output to extract receipt fields.
class OcrService {
  // Mapping of 3-letter month abbreviations to month numbers.
  static const Map<String, int> _monthMap = {
    'JAN': 1, 'FEB': 2, 'MAR': 3, 'APR': 4,  'MAY': 5,  'JUN': 6,
    'JUL': 7, 'AUG': 8, 'SEP': 9, 'OCT': 10, 'NOV': 11, 'DEC': 12,
  };

  // ---------------------------------------------------------------------------
  // Public API
  // ---------------------------------------------------------------------------

  /// Runs ML Kit text recognition on the image at [imagePath].
  Future<String> recognizeText(String imagePath) async {
    final inputImage = InputImage.fromFilePath(imagePath);
    final textRecognizer = TextRecognizer(
      script: TextRecognitionScript.latin,
    );
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } finally {
      textRecognizer.close();
    }
  }

  /// Runs OCR then parses the result into structured receipt data.
  Future<ReceiptData> processReceipt(String imagePath) async {
    final rawText = await recognizeText(imagePath);
    return parseReceipt(rawText);
  }

  /// Parses raw OCR text into a [ReceiptData] with per-field confidence.
  ReceiptData parseReceipt(String rawText) {
    final processed = _preprocess(rawText);
    final (merchant, merchantConf) = _extractMerchant(rawText, processed);
    final (amount, amountConf) = _extractAmount(processed);
    final (date, dateConf) = _extractDate(processed);

    return ReceiptData(
      merchant: merchant,
      amount: amount,
      date: date,
      rawText: rawText,
      merchantConfidence: merchantConf,
      amountConfidence: amountConf,
      dateConfidence: dateConf,
    );
  }

  // ---------------------------------------------------------------------------
  // Step 1: Preprocessing
  // ---------------------------------------------------------------------------

  /// Normalizes raw OCR text before regex parsing.
  ///
  /// - Trims and collapses whitespace within each line
  /// - Converts to uppercase for case-insensitive matching
  /// - Fixes common OCR digit misreads only when flanked by digits:
  ///   O → 0, L → 1, S → 5
  String _preprocess(String raw) {
    // Normalize whitespace line by line, then rejoin
    final lines = raw
        .split('\n')
        .map((l) => l.trim().replaceAll(RegExp(r'\s+'), ' '))
        .toList();
    var text = lines.join('\n');

    // Uppercase everything for uniform matching
    text = text.toUpperCase();

    // Fix OCR misreads only when the character is surrounded by digits.
    // We capture the surrounding digits to avoid consuming them in the match,
    // then reconstruct: digit + corrected char + digit.
    text = text.replaceAllMapped(RegExp(r'(\d)O(\d)'), (m) => '${m[1]}0${m[2]}');
    text = text.replaceAllMapped(RegExp(r'(\d)L(\d)'), (m) => '${m[1]}1${m[2]}');
    text = text.replaceAllMapped(RegExp(r'(\d)S(\d)'), (m) => '${m[1]}5${m[2]}');

    return text;
  }

  // ---------------------------------------------------------------------------
  // Step 2: Merchant
  // ---------------------------------------------------------------------------

  /// Returns the merchant name and its confidence level.
  ///
  /// Strategy:
  /// - Skips lines shorter than 3 chars, pure-numeric, date-like, or address-like.
  /// - Prefers lines where digits make up less than 40% of characters (high confidence).
  /// - Falls back to the first valid line, or the very first raw line.
  (String?, OcrConfidence) _extractMerchant(String rawText, String processed) {
    final rawLines = rawText
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();
    final procLines = processed
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final datePattern =
        RegExp(r'^\d{1,2}[\/\-\. ]\d{1,2}[\/\-\. ]\d{2,4}$');
    final pureNumberPattern = RegExp(r'^[\d\s\.,\-\+\*:]+$');
    // Malaysian address keywords
    final addressPattern =
        RegExp(r'\b(JLN|JALAN|NO\.|LOT|FLOOR|LEVEL|NO,|TINGKAT)\b');

    String? firstValidLine; // best-effort fallback

    for (int i = 0; i < procLines.length; i++) {
      final pLine = procLines[i];
      final rawLine = i < rawLines.length ? rawLines[i] : pLine;

      if (rawLine.length < 3) continue;
      if (pureNumberPattern.hasMatch(pLine)) continue;
      if (datePattern.hasMatch(pLine)) continue;
      if (addressPattern.hasMatch(pLine)) continue;

      final alphaCount = RegExp(r'[A-Z]').allMatches(pLine).length;
      if (alphaCount < 3) continue;

      firstValidLine ??= rawLine; // remember first passing line

      // High-confidence: alphabetic characters dominate (not a data row)
      final digitCount = RegExp(r'\d').allMatches(pLine).length;
      if (digitCount < pLine.length * 0.4) {
        return (rawLine, OcrConfidence.high);
      }
    }

    // Low-confidence fallback
    if (firstValidLine != null) return (firstValidLine, OcrConfidence.low);
    if (rawLines.isNotEmpty) return (rawLines.first, OcrConfidence.low);
    return (null, OcrConfidence.none);
  }

  // ---------------------------------------------------------------------------
  // Step 3: Amount
  // ---------------------------------------------------------------------------

  /// Returns the total amount and its confidence level.
  ///
  /// Priority order (per line classification):
  ///   1. Line contains TOTAL / GRAND TOTAL / AMOUNT DUE / JUMLAH / BAYARAN / CHARGE
  ///      → returns the last value on such a line (high confidence)
  ///   2. Line contains SUBTOTAL / SUB-TOTAL
  ///      → last value (low confidence)
  ///   3. Largest decimal value on any other line, excluding tax lines
  ///      → fallback (low confidence)
  ///   4. Tax lines (GST / SST / TAX / SERVICE CHARGE) used only if nothing else found.
  (double?, OcrConfidence) _extractAmount(String text) {
    final p1Pattern = RegExp(
      r'\b(GRAND\s*TOTAL|TOTAL\s*(?:AMOUNT|DUE|SALES|PAYMENT)?'
      r'|AMOUNT\s*DUE|JUMLAH|BAYARAN|CHARGE)\b',
    );
    final p2Pattern = RegExp(r'\b(SUBTOTAL|SUB[\s\-]TOTAL)\b');
    final taxPattern =
        RegExp(r'\b(GST|SST|TAX|SERVICE\s*CHARGE)\b');
    // Matches: optional RM/MYR prefix, then a decimal number
    final numberPattern =
        RegExp(r'(?:RM|MYR)?\s*([\d,]+\.\d{1,2})\b');

    final p1Values = <double>[];
    final p2Values = <double>[];
    final p3Values = <double>[];
    final taxValues = <double>[];

    for (final line in text.split('\n')) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) continue;

      final isP1 = p1Pattern.hasMatch(trimmed);
      final isP2 = !isP1 && p2Pattern.hasMatch(trimmed);
      final isTax = taxPattern.hasMatch(trimmed);

      for (final match in numberPattern.allMatches(trimmed)) {
        final valueStr = match.group(1)!.replaceAll(',', '');
        final value = double.tryParse(valueStr);
        if (value == null || value <= 0) continue;

        if (isTax) {
          taxValues.add(value);
        } else if (isP1) {
          p1Values.add(value);
        } else if (isP2) {
          p2Values.add(value);
        } else {
          p3Values.add(value);
        }
      }
    }

    if (p1Values.isNotEmpty) {
      return (p1Values.last, OcrConfidence.high);
    }
    if (p2Values.isNotEmpty) {
      return (p2Values.last, OcrConfidence.low);
    }
    if (p3Values.isNotEmpty) {
      return (p3Values.reduce((a, b) => a > b ? a : b), OcrConfidence.low);
    }
    if (taxValues.isNotEmpty) {
      return (taxValues.reduce((a, b) => a > b ? a : b), OcrConfidence.low);
    }
    return (null, OcrConfidence.none);
  }

  // ---------------------------------------------------------------------------
  // Step 4: Date
  // ---------------------------------------------------------------------------

  /// Returns a date and its confidence level.
  ///
  /// Formats tried in order (most to least specific):
  ///   1. D/DD MMM YYYY  (e.g. 5 APR 2025, 05 APR 2025)  → high
  ///   2. YYYY-MM-DD / YYYY/MM/DD                          → high
  ///   3. DD/MM/YYYY, DD-MM-YYYY, DD MM YYYY, DD.MM.YYYY  → low
  (DateTime?, OcrConfidence) _extractDate(String text) {
    // Format 1: named month  "DD MMM YYYY"
    final monthNames = _monthMap.keys.join('|');
    final namedMonthRegex = RegExp(
      r'\b(\d{1,2})\s+(' + monthNames + r')\s+(\d{2,4})\b',
    );
    for (final match in namedMonthRegex.allMatches(text)) {
      final day = int.parse(match.group(1)!);
      final month = _monthMap[match.group(2)]!;
      var year = int.parse(match.group(3)!);
      if (year < 100) year += year > 50 ? 1900 : 2000;
      final date = _tryParseDate(day, month, year);
      if (date != null) return (date, OcrConfidence.high);
    }

    // Format 2: ISO  YYYY[-/.]MM[-/.]DD
    final isoRegex =
        RegExp(r'\b(\d{4})[-\/\.](\d{1,2})[-\/\.](\d{1,2})\b');
    for (final match in isoRegex.allMatches(text)) {
      final date = _tryParseDate(
        int.parse(match.group(3)!),
        int.parse(match.group(2)!),
        int.parse(match.group(1)!),
      );
      if (date != null) return (date, OcrConfidence.high);
    }

    // Format 3: DD/MM/YYYY, DD-MM-YYYY, DD MM YYYY, DD.MM.YYYY
    final dmyRegex =
        RegExp(r'\b(\d{1,2})[\/\-\. ](\d{1,2})[\/\-\. ](\d{2,4})\b');
    for (final match in dmyRegex.allMatches(text)) {
      final part1 = int.parse(match.group(1)!);
      final part2 = int.parse(match.group(2)!);
      var part3 = int.parse(match.group(3)!);
      if (part3 < 100) part3 += part3 > 50 ? 1900 : 2000;

      // Try DD/MM/YYYY (Malaysian standard) first
      final dateDmy = _tryParseDate(part1, part2, part3);
      if (dateDmy != null) return (dateDmy, OcrConfidence.low);

      // Fallback: MM/DD/YYYY
      final dateMdy = _tryParseDate(part2, part1, part3);
      if (dateMdy != null) return (dateMdy, OcrConfidence.low);
    }

    return (null, OcrConfidence.none);
  }

  // ---------------------------------------------------------------------------
  // Helper
  // ---------------------------------------------------------------------------

  /// Creates a [DateTime] from components, returning null for invalid dates
  /// (e.g. month 13, Feb 30, year outside 2000–2100).
  DateTime? _tryParseDate(int day, int month, int year) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;
    try {
      final date = DateTime(year, month, day);
      // Guard against overflow (e.g. Feb 30 silently rolls to Mar 2)
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
