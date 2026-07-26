/// A subcategory: a display name plus an optional SVG icon key. Subcategories
/// inherit their parent category's colour (they have no colour of their own).
class SubcategoryModel {
  final String name;

  /// Key of the chosen subcategory SVG icon (see `CategoryGlyphs.subcategoryKeys`).
  final String? iconKey;

  const SubcategoryModel({required this.name, this.iconKey});

  Map<String, dynamic> toJson() => {'name': name, 'iconKey': iconKey};

  /// Accepts the current object form, or a bare string (legacy backups where a
  /// subcategory was just its name).
  factory SubcategoryModel.fromJson(dynamic json) {
    if (json is String) return SubcategoryModel(name: json);
    final map = json as Map<String, dynamic>;
    return SubcategoryModel(
      name: map['name'] as String,
      iconKey: map['iconKey'] as String?,
    );
  }

  SubcategoryModel copyWith({String? name, String? iconKey}) => SubcategoryModel(
        name: name ?? this.name,
        iconKey: iconKey ?? this.iconKey,
      );

  // Identity is by name (case-sensitive) so lists dedupe/replace sensibly.
  @override
  bool operator ==(Object other) =>
      other is SubcategoryModel && other.name == name;

  @override
  int get hashCode => name.hashCode;
}

/// A transaction category with a display name, an SVG icon, a chosen background
/// colour, and optional subcategories.
///
/// [iconKey] references an SVG in `CategoryGlyphs.categoryKeys`. [colorValue] is
/// the ARGB value of the user-chosen icon background colour (null falls back to
/// a legacy/default colour). Both are nullable so older saved categories still
/// load.
class CategoryModel {
  final String name;
  final String? iconKey;

  /// ARGB value of the chosen icon background colour, or null (legacy/default).
  final int? colorValue;

  /// Legacy emoji from before icons were selectable. Kept for old data.
  final String emoji;

  /// Child categories (e.g. Breakfast / Lunch under Food).
  final List<SubcategoryModel> subcategories;

  const CategoryModel({
    required this.name,
    this.iconKey,
    this.colorValue,
    this.emoji = '',
    this.subcategories = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'iconKey': iconKey,
        'colorValue': colorValue,
        'emoji': emoji,
        'subcategories': subcategories.map((s) => s.toJson()).toList(),
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        name: json['name'] as String,
        iconKey: json['iconKey'] as String?,
        colorValue: json['colorValue'] as int?,
        emoji: (json['emoji'] as String?) ?? '',
        subcategories: (json['subcategories'] as List<dynamic>?)
                ?.map(SubcategoryModel.fromJson)
                .toList() ??
            const [],
      );

  CategoryModel copyWith({
    String? name,
    String? iconKey,
    int? colorValue,
    String? emoji,
    List<SubcategoryModel>? subcategories,
  }) {
    return CategoryModel(
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
      colorValue: colorValue ?? this.colorValue,
      emoji: emoji ?? this.emoji,
      subcategories: subcategories ?? this.subcategories,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is CategoryModel && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
