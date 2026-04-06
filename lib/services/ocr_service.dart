import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// Holds the parsed data extracted from a receipt image.
class ReceiptData {
  final String? merchant;
  final double? amount;
  final DateTime? date;
  final String rawText;

  ReceiptData({
    this.merchant,
    this.amount,
    this.date,
    required this.rawText,
  });
}

/// Handles on-device OCR using Google ML Kit Text Recognition v2
/// and parses the raw text output to extract receipt fields.
class OcrService {
  /// Runs ML Kit text recognition on the image at [imagePath].
  /// Returns the full recognized text string.
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

  /// Runs OCR on the image and parses the result into structured receipt data.
  Future<ReceiptData> processReceipt(String imagePath) async {
    final rawText = await recognizeText(imagePath);
    return parseReceipt(rawText);
  }

  /// Parses raw OCR text to extract merchant, amount, and date.
  ReceiptData parseReceipt(String rawText) {
    return ReceiptData(
      merchant: _extractMerchant(rawText),
      amount: _extractAmount(rawText),
      date: _extractDate(rawText),
      rawText: rawText,
    );
  }

  /// Extracts the merchant name from the first meaningful line.
  ///
  /// Skips lines that are purely numeric, look like dates, or are too short
  /// to be a store name (< 3 alphabetic characters).
  String? _extractMerchant(String text) {
    final lines = text
        .split('\n')
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList();

    final datePattern = RegExp(r'^\d{1,2}[\/\-\.]\d{1,2}[\/\-\.]\d{2,4}$');
    final pureNumberPattern = RegExp(r'^[\d\s\.,\-\+]+$');

    for (final line in lines) {
      // Skip lines that are just numbers or dates
      if (pureNumberPattern.hasMatch(line)) continue;
      if (datePattern.hasMatch(line)) continue;

      // Must have at least 3 alphabetic characters to be a merchant name
      final alphaCount = RegExp(r'[a-zA-Z]').allMatches(line).length;
      if (alphaCount >= 3) return line;
    }

    return null;
  }

  /// Extracts the total amount from the receipt text.
  ///
  /// Strategy:
  /// 1. Look for keyword-based totals (TOTAL, JUMLAH, AMOUNT DUE, etc.)
  ///    with optional RM/MYR currency prefix. Takes the last match (grand total).
  /// 2. If no keyword match, fall back to the largest currency value found.
  double? _extractAmount(String text) {
    // Keyword-based extraction: look for total-related keywords followed by a number
    final keywordRegex = RegExp(
      r'(?:GRAND\s*TOTAL|TOTAL\s*(?:AMOUNT|DUE|SALES|PAYMENT)?|JUMLAH|AMOUNT\s*DUE|BAYARAN)'
      r'[:\s]*'
      r'(?:RM|MYR)?\s*'
      r'([\d,]+\.?\d*)',
      caseSensitive: false,
    );

    final keywordMatches = keywordRegex.allMatches(text).toList();
    if (keywordMatches.isNotEmpty) {
      // Take the last match — grand total typically appears after subtotals
      final lastMatch = keywordMatches.last;
      final valueStr = lastMatch.group(1)?.replaceAll(',', '');
      if (valueStr != null) {
        final parsed = double.tryParse(valueStr);
        if (parsed != null && parsed > 0) return parsed;
      }
    }

    // Fallback: find all currency-like numbers and return the largest
    final numberRegex = RegExp(
      r'(?:RM|MYR)\s*([\d,]+\.\d{2})',
      caseSensitive: false,
    );
    final numberMatches = numberRegex.allMatches(text);

    double? largest;
    for (final match in numberMatches) {
      final valueStr = match.group(1)?.replaceAll(',', '');
      if (valueStr != null) {
        final parsed = double.tryParse(valueStr);
        if (parsed != null && (largest == null || parsed > largest)) {
          largest = parsed;
        }
      }
    }

    // Last resort: find any decimal number that looks like a price
    if (largest == null) {
      final anyNumberRegex = RegExp(r'([\d,]+\.\d{2})\b');
      final anyMatches = anyNumberRegex.allMatches(text);
      for (final match in anyMatches) {
        final valueStr = match.group(1)?.replaceAll(',', '');
        if (valueStr != null) {
          final parsed = double.tryParse(valueStr);
          if (parsed != null && (largest == null || parsed > largest)) {
            largest = parsed;
          }
        }
      }
    }

    return largest;
  }

  /// Extracts a date from the receipt text.
  ///
  /// Supports common formats: DD/MM/YYYY, DD-MM-YYYY, DD.MM.YYYY
  /// and YYYY-MM-DD (ISO format). Malaysian receipts typically use DD/MM/YYYY.
  DateTime? _extractDate(String text) {
    // Try ISO format first: YYYY-MM-DD
    final isoRegex = RegExp(r'\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b');
    final isoMatch = isoRegex.firstMatch(text);
    if (isoMatch != null) {
      final date = _tryParseDate(
        int.parse(isoMatch.group(3)!), // day
        int.parse(isoMatch.group(2)!), // month
        int.parse(isoMatch.group(1)!), // year
      );
      if (date != null) return date;
    }

    // Try DD/MM/YYYY (Malaysian standard)
    final dmyRegex = RegExp(r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b');
    final allMatches = dmyRegex.allMatches(text);

    for (final match in allMatches) {
      final part1 = int.parse(match.group(1)!);
      final part2 = int.parse(match.group(2)!);
      var part3 = int.parse(match.group(3)!);

      // Convert 2-digit year to 4-digit
      if (part3 < 100) {
        part3 += part3 > 50 ? 1900 : 2000;
      }

      // Try DD/MM/YYYY first (Malaysian standard)
      final date = _tryParseDate(part1, part2, part3);
      if (date != null) return date;

      // Fallback: try MM/DD/YYYY
      final dateMdy = _tryParseDate(part2, part1, part3);
      if (dateMdy != null) return dateMdy;
    }

    return null;
  }

  /// Validates and creates a DateTime from day, month, year components.
  /// Returns null if the values form an invalid date.
  DateTime? _tryParseDate(int day, int month, int year) {
    if (month < 1 || month > 12) return null;
    if (day < 1 || day > 31) return null;
    if (year < 2000 || year > 2100) return null;

    try {
      final date = DateTime(year, month, day);
      // Verify the date didn't overflow (e.g., Feb 30 -> Mar 2)
      if (date.day != day || date.month != month || date.year != year) {
        return null;
      }
      return date;
    } catch (_) {
      return null;
    }
  }
}
