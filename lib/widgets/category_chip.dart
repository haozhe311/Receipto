import 'package:flutter/material.dart';
import 'package:receipto/constants/app_constants.dart';

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
      child: ChoiceChip(
        label: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected ? Colors.white : color,
            ),
            const SizedBox(width: 4),
            Text(category),
          ],
        ),
        selected: isSelected,
        selectedColor: color,
        labelStyle: TextStyle(
          color: isSelected ? Colors.white : null,
        ),
        onSelected: (_) => onTap(),
      ),
    );
  }
}
