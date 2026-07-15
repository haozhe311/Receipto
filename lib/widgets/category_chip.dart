import 'package:flutter/material.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';

/// A selectable chip representing a transaction category.
///
/// Shows the category's icon swatch, resolved from [iconKey] (or the built-in
/// match on [category]). Legacy categories saved before icon swatches existed
/// — no [iconKey] and not built-in — fall back to displaying [emoji].
///
/// Used in the home screen filter bar and in the add/edit category selector.
class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  /// Key of the category's icon swatch, when it has one.
  final String? iconKey;

  /// Legacy emoji, shown only when no icon swatch can be resolved.
  final String emoji;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.iconKey,
    this.emoji = '',
  });

  @override
  Widget build(BuildContext context) {
    final option = CategoryIcons.resolve(category, iconKey);
    final hasSwatch =
        iconKey != null || CategoryIcons.builtInKeyFor(category) != null;
    final isCustom = !hasSwatch;

    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
          decoration: BoxDecoration(
            color: isSelected ? AppTheme.goldDark : AppTheme.surface,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: isSelected ? AppTheme.gold : AppTheme.border,
              width: isSelected ? 1.5 : 1,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Icon swatch; legacy categories without one show their emoji.
              if (isCustom && emoji.isNotEmpty)
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 14, height: 1),
                )
              else
                Icon(
                  option.icon,
                  size: 15,
                  color: isSelected ? AppTheme.gold : option.color,
                ),
              const SizedBox(width: 5),
              Text(
                category,
                style: TextStyle(
                  color: isSelected ? AppTheme.gold : AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight:
                      isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
