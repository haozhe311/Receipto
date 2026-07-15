/// A transaction category with a display name, an icon swatch, and optional
/// subcategories.
///
/// [iconKey] references a preset in `CategoryIcons`. It is nullable so that
/// categories saved before icons became selectable still load: those fall back
/// to their built-in icon (matched on [name]), then to [emoji], then to a
/// default icon.
class CategoryModel {
  final String name;

  /// Key of the selected icon + colour swatch (see `CategoryIcons.presets`).
  final String? iconKey;

  /// Legacy emoji from before icon swatches existed. No longer editable; kept
  /// so older saved categories still render something meaningful.
  final String emoji;

  /// Child categories (e.g. Groceries / Dining / Coffee under Food).
  final List<String> subcategories;

  const CategoryModel({
    required this.name,
    this.iconKey,
    this.emoji = '',
    this.subcategories = const [],
  });

  Map<String, dynamic> toJson() => {
        'name': name,
        'iconKey': iconKey,
        'emoji': emoji,
        'subcategories': subcategories,
      };

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        name: json['name'] as String,
        iconKey: json['iconKey'] as String?,
        emoji: (json['emoji'] as String?) ?? '',
        subcategories:
            (json['subcategories'] as List<dynamic>?)?.cast<String>() ??
                const [],
      );

  CategoryModel copyWith({
    String? name,
    String? iconKey,
    String? emoji,
    List<String>? subcategories,
  }) {
    return CategoryModel(
      name: name ?? this.name,
      iconKey: iconKey ?? this.iconKey,
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
