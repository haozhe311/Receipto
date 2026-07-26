import 'package:flutter/material.dart';
import 'package:receipto/constants/category_glyphs.dart';
import 'package:receipto/constants/theme.dart';

/// Grid of the 11 category SVG icons. The selected icon is highlighted; icons
/// are tinted neutral (unselected) or accent (selected) so the grid reads
/// clearly regardless of the chosen background colour.
class CategoryIconPickerGrid extends StatelessWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  const CategoryIconPickerGrid({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _GlyphPickerGrid(
      keys: CategoryGlyphs.categoryKeys,
      assetFor: CategoryGlyphs.categoryAsset,
      selectedKey: selectedKey,
      onSelected: onSelected,
      crossAxisCount: 5,
    );
  }
}

/// Grid of the 45 subcategory SVG icons.
class SubcategoryIconPickerGrid extends StatelessWidget {
  final String? selectedKey;
  final ValueChanged<String> onSelected;

  const SubcategoryIconPickerGrid({
    super.key,
    required this.selectedKey,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return _GlyphPickerGrid(
      keys: CategoryGlyphs.subcategoryKeys,
      assetFor: CategoryGlyphs.subcategoryAsset,
      selectedKey: selectedKey,
      onSelected: onSelected,
      crossAxisCount: 5,
    );
  }
}

class _GlyphPickerGrid extends StatelessWidget {
  final List<String> keys;
  final String Function(String) assetFor;
  final String? selectedKey;
  final ValueChanged<String> onSelected;
  final int crossAxisCount;

  const _GlyphPickerGrid({
    required this.keys,
    required this.assetFor,
    required this.selectedKey,
    required this.onSelected,
    required this.crossAxisCount,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: crossAxisCount,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final key in keys)
          _GlyphCell(
            assetPath: assetFor(key),
            selected: key == selectedKey,
            onTap: () => onSelected(key),
          ),
      ],
    );
  }
}

class _GlyphCell extends StatelessWidget {
  final String assetPath;
  final bool selected;
  final VoidCallback onTap;

  const _GlyphCell({
    required this.assetPath,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        decoration: BoxDecoration(
          color: selected ? AppTheme.goldDark : AppTheme.surfaceHigh,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: selected ? AppTheme.gold : AppTheme.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Center(
          child: CategoryGlyph(
            assetPath: assetPath,
            color: selected ? AppTheme.gold : AppTheme.textPrimary,
            size: 24,
          ),
        ),
      ),
    );
  }
}

/// Grid of the 20 selectable category background colours.
class ColorPickerGrid extends StatelessWidget {
  final int? selectedValue;
  final ValueChanged<int> onSelected;

  const ColorPickerGrid({
    super.key,
    required this.selectedValue,
    required this.onSelected,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.count(
      crossAxisCount: 5,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 10,
      crossAxisSpacing: 10,
      children: [
        for (final color in CategoryGlyphs.palette)
          _ColorCell(
            color: color,
            selected: color.toARGB32() == selectedValue,
            onTap: () => onSelected(color.toARGB32()),
          ),
      ],
    );
  }
}

class _ColorCell extends StatelessWidget {
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _ColorCell({
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(100),
      child: Container(
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: selected ? AppTheme.textPrimary : Colors.white,
            width: selected ? 3 : 2,
          ),
          boxShadow: [
            BoxShadow(
              color: color.withValues(alpha: 0.35),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: selected
            ? const Icon(Icons.check, color: Colors.white, size: 18)
            : null,
      ),
    );
  }
}
