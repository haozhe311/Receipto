import 'package:flutter/material.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';

/// A selectable chip representing a transaction category.
///
/// Built-in categories (those present in [AppConstants.categoryIcons]) display
/// their Material icon. Custom categories display [emoji] as text instead.
///
/// Used in the home screen filter bar and in the add/edit category selector.
class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  /// Emoji string shown for custom categories that have no Material icon.
  /// Ignored when the category exists in [AppConstants.categoryIcons].
  final String emoji;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
    this.emoji = '',
  });

  @override
  Widget build(BuildContext context) {
    final builtInIcon = AppConstants.categoryIcons[category];
    final builtInColor = AppConstants.categoryColors[category] ?? Colors.grey;
    final isCustom = builtInIcon == null;

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
              // Built-in categories: Material icon; custom categories: emoji text.
              if (isCustom && emoji.isNotEmpty)
                Text(
                  emoji,
                  style: const TextStyle(fontSize: 14, height: 1),
                )
              else
                Icon(
                  builtInIcon ?? Icons.more_horiz,
                  size: 15,
                  color: isSelected ? AppTheme.gold : builtInColor,
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
