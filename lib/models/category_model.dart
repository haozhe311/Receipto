/// A transaction category with a display name and an emoji icon.
///
/// Built-in categories (Food, Transport, etc.) carry a default emoji that is
/// shown in the Manage Categories list. Custom categories show their emoji
/// everywhere, including the category chip, since they have no Material icon.
class CategoryModel {
  final String name;

  /// Emoji shown in the Manage Categories list and (for custom categories)
  /// in category chips. Built-in categories use their Material icon in chips.
  final String emoji;

  const CategoryModel({required this.name, required this.emoji});

  Map<String, dynamic> toJson() => {'name': name, 'emoji': emoji};

  factory CategoryModel.fromJson(Map<String, dynamic> json) => CategoryModel(
        name: json['name'] as String,
        emoji: (json['emoji'] as String?) ?? '',
      );

  @override
  bool operator ==(Object other) =>
      other is CategoryModel && other.name == name;

  @override
  int get hashCode => name.hashCode;
}
