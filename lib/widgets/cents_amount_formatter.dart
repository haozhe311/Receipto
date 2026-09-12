import 'package:flutter/services.dart';

/// Turns a plain amount field into "cents-first" calculator-style entry:
/// each digit typed is appended to the right and the existing digits shift
/// left, e.g. typing 5, then 3, then 8 in turn produces 0.05, then 0.53,
/// then 5.38 — so the user never has to type the decimal point themselves.
/// Backspacing removes the rightmost digit the same way, all the way back
/// down to an empty field.
///
/// Tracks the entered digits internally rather than re-deriving them from
/// the displayed text on every keystroke, which would get permanently stuck
/// at "0.00" once backspacing reached it (removing a character there just
/// reformats back to "0.00"). If the field's text is ever changed by
/// something other than this formatter — a pre-filled value when editing an
/// existing amount, an OCR scan, a Split Bill result — the next edit resyncs
/// from whatever is actually displayed first, so it stays correct regardless
/// of how the field got there.
class CentsAmountInputFormatter extends TextInputFormatter {
  static final RegExp _nonDigits = RegExp(r'[^0-9]');

  /// Caps the digit string so the value can't grow unbounded — 10 digits is
  /// up to RM 99,999,999.99, far beyond any real transaction.
  static const int _maxDigits = 10;

  String _digits = '';

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Something other than this formatter set the field's text since our
    // last edit — resync our digit tracking to match it before continuing.
    if (oldValue.text != _render(_digits)) {
      _digits = oldValue.text.replaceAll(_nonDigits, '');
    }

    final oldDigitCount = oldValue.text.replaceAll(_nonDigits, '').length;
    final newDigitsOnly = newValue.text.replaceAll(_nonDigits, '');
    final delta = newDigitsOnly.length - oldDigitCount;

    if (delta > 0) {
      // One or more digits were typed or pasted at the cursor — append just
      // the newly added ones.
      _digits += newDigitsOnly.substring(newDigitsOnly.length - delta);
      if (_digits.length > _maxDigits) {
        _digits = _digits.substring(_digits.length - _maxDigits);
      }
    } else if (delta < 0) {
      // Backspace/delete — drop the same number of digits from the end.
      final removed = -delta;
      _digits = _digits.length > removed
          ? _digits.substring(0, _digits.length - removed)
          : '';
    }
    // delta == 0: a non-digit keystroke (e.g. ".") changed nothing — ignore it.

    final formatted = _render(_digits);
    return TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(offset: formatted.length),
    );
  }

  /// Renders a digit string as a "dollars.cents" amount, treating it as the
  /// value in cents (e.g. "538" → "5.38"), or "" when there are no digits.
  static String _render(String digits) {
    if (digits.isEmpty) return '';
    final cents = int.parse(digits);
    final dollars = cents ~/ 100;
    final centsPart = (cents % 100).toString().padLeft(2, '0');
    return '$dollars.$centsPart';
  }
}
