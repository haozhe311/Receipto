/// Confidence level for each parsed receipt field.
enum OcrConfidence {
  /// Matched using a high-confidence keyword (e.g. TOTAL, GRAND TOTAL), or
  /// returned directly by the vision model.
  high,

  /// Matched using a fallback heuristic.
  low,

  /// Field could not be extracted from the receipt.
  none,
}

/// A single line item parsed from a receipt.
class ReceiptItem {
  final String name;

  /// Unit price (per single item).
  final double price;

  /// Quantity shown on the receipt for this line (defaults to 1).
  final int qty;

  const ReceiptItem({required this.name, required this.price, this.qty = 1});
}

/// Holds the data extracted from a receipt or bank-transfer screenshot.
class ReceiptData {
  final String? merchant;
  final double? amount;
  final DateTime? date;

  /// Best-effort list of individual line items (name + price). May be empty
  /// (e.g. bank transfer screenshots have none) — callers should let the
  /// user review and edit it.
  final List<ReceiptItem> items;

  /// Service charge percentage detected on the receipt (e.g. 10 for "10%").
  final double? serviceRate;

  /// Tax / SST / GST percentage detected on the receipt (e.g. 6 for "6%").
  final double? taxRate;

  /// Best-effort category/subcategory for the transaction (a preset
  /// subcategory name, e.g. "Fuel"), or null if it couldn't be classified.
  final String? category;

  /// Original raw text/response kept for debugging, when available.
  final String rawText;

  final OcrConfidence merchantConfidence;
  final OcrConfidence amountConfidence;
  final OcrConfidence dateConfidence;

  ReceiptData({
    this.merchant,
    this.amount,
    this.date,
    this.items = const [],
    this.serviceRate,
    this.taxRate,
    this.category,
    this.rawText = '',
    this.merchantConfidence = OcrConfidence.none,
    this.amountConfidence = OcrConfidence.none,
    this.dateConfidence = OcrConfidence.none,
  });
}

/// Best-effort keyword classifier used as a fallback when the vision model's
/// own category guess doesn't match one of the app's preset subcategories.
class ReceiptCategoryGuesser {
  ReceiptCategoryGuesser._();

  /// Keyword rules mapping a merchant/item hint → a preset subcategory name.
  /// Order matters: the first rule whose keyword appears wins. Values are the
  /// canonical preset subcategory names; callers should confirm the result is
  /// still a selectable category before applying it.
  static const List<(String, List<String>)> _categoryKeywordRules = [
    ('Fuel', ['petronas', 'shell', 'petron', 'bhp', 'caltex', 'petrol', 'fuel']),
    ('Delivery', ['grabfood', 'foodpanda', 'shopeefood', 'food panda']),
    ('Taxi', ['grab', 'indrive', 'airport taxi']),
    ('Tolls', ['toll', 'plus ', 'touch n go toll', 'lpt', 'nkve']),
    ('Parking', ['parking', 'car park', 'wilson']),
    ('Train', ['ktm', ' ets', 'rapidkl', 'mrt', 'lrt']),
    ('Flight', ['airasia', 'air asia', 'batik air', 'malaysia airlines', 'firefly']),
    ('Drinks', ['tealive', 'zus', 'starbucks', 'boba', 'milk tea', 'chagee',
      'coffee', 'kopi ']),
    ('Groceries', ['econsave', 'aeon', 'tesco', 'lotus', 'nsk', 'mydin',
      'giant', 'speedmart', 'jaya grocer', 'grocer', 'supermarket', 'mart']),
    ('Snacks', ['7-eleven', '7 eleven', 'seven eleven', 'bakery', 'kk super',
      'family mart', 'vending']),
    ('Movies', ['gsc', 'tgv', 'mbo', 'cinema', 'cineplex', 'lotus five star']),
    ('Games', ['steam', 'playstation', 'nintendo', 'google play', 'xbox']),
    ('Subscriptions', ['netflix', 'spotify', 'youtube premium', 'disney',
      'icloud', 'notion']),
    ('Books', ['mph', 'popular', 'kinokuniya', 'bookstore', 'book store',
      'borders']),
    ('Medicine', ['pharmacy', 'watsons', 'guardian', 'caring', 'big pharmacy',
      'farmasi']),
    ('Doctor', ['clinic', 'klinik', 'hospital', 'medical centre', 'poliklinik']),
    ('Clothing', ['uniqlo', 'padini', 'h&m', 'zara', 'cotton on', 'brands outlet',
      'nike', 'adidas']),
    ('Electricity Bill', ['tnb', 'tenaga nasional']),
    ('Water Bill', ['air selangor', 'syabas', 'lap ', 'pba', 'ranhill']),
    ('Home Wi-Fi', ['unifi', 'tm ', 'time home', 'maxis home']),
    ('Internet', ['hotlink', 'celcom', 'digi', 'umobile', 'u mobile', 'yes 4g']),
    ('Stationery', ['mr diy', 'mr. diy', 'stationery', 'stationary']),
  ];

  /// Best-effort guess of a preset subcategory from the merchant name (and, as
  /// a weak secondary signal, item names). Returns a canonical subcategory name
  /// like "Fuel", or null when nothing matches. Generic food merchants are left
  /// null on purpose — meal (Breakfast/Lunch/Dinner) can't be told apart here,
  /// so the vision model's own category call (or the user) decides.
  static String? guessCategory(String? merchant, {List<ReceiptItem> items = const []}) {
    final hay = [
      merchant ?? '',
      for (final i in items) i.name,
    ].join(' ').toLowerCase();
    if (hay.trim().isEmpty) return null;
    for (final (category, keywords) in _categoryKeywordRules) {
      for (final k in keywords) {
        if (hay.contains(k)) return category;
      }
    }
    return null;
  }
}
