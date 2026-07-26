import 'package:flutter/material.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/theme.dart';

/// A selectable chip representing a transaction category.
///
/// Shows the category's SVG glyph, resolved from [iconKey] and tinted with the
/// category's colour (or accent when selected).
///
/// Used in the add/edit category selector.
class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  /// Key of the category's icon glyph, when it has one.
  final String? iconKey;

  /// ARGB of the category's chosen colour (null falls back to a preset).
  final int? colorValue;

  /// Legacy emoji. Retained for API compatibility; no longer displayed.
  final String emoji;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.iconKey,
    this.colorValue,
    this.emoji = '',
  });

  @override
  Widget build(BuildContext context) {
    final visual = CategoryGlyphs.categoryVisual(
      name: category,
      iconKey: iconKey,
      colorValue: colorValue,
    );

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
              CategoryGlyph(
                assetPath: visual.assetPath,
                color: isSelected ? AppTheme.gold : visual.color,
                size: 15,
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
