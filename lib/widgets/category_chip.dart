import 'package:flutter/material.dart';
import 'package:receipto/constants/app_constants.dart';
import 'package:receipto/constants/theme.dart';

/// A selectable chip representing a transaction category.
///
/// Used in the home screen for filtering and in the add/edit form
/// for category selection.
class CategoryChip extends StatelessWidget {
  final String category;
  final bool isSelected;
  final VoidCallback onTap;

  const CategoryChip({
    super.key,
    required this.category,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = AppConstants.categoryIcons[category] ?? Icons.more_horiz;
    final color = AppConstants.categoryColors[category] ?? Colors.grey;

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
              Icon(
                icon,
                size: 15,
                color: isSelected ? AppTheme.gold : color,
              ),
              const SizedBox(width: 5),
              Text(
                category,
                style: TextStyle(
                  color: isSelected ? AppTheme.gold : AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
