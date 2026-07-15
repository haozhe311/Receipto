import 'package:flutter/material.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';

/// A grid of preset icon + colour swatches. The selected swatch is marked with
/// a gold ring. Shared by the Add Category dialog, the Category Detail screen,
/// and the icon picker sheet so selection looks identical everywhere.
class CategoryIconGrid extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final int crossAxisCount;

  const CategoryIconGrid({
    super.key,
    required this.selectedKey,
    required this.onSelected,
    this.crossAxisCount = 5,
  });

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.zero,
      itemCount: CategoryIcons.presets.length,
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      itemBuilder: (context, i) {
        final option = CategoryIcons.presets[i];
        final isSelected = option.key == selectedKey;
        return GestureDetector(
          onTap: () => onSelected(option.key),
          child: Container(
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: option.color.withAlpha(38),
              border: Border.all(
                color: isSelected ? AppTheme.gold : AppTheme.border,
                width: isSelected ? 2 : 1,
              ),
            ),
            child: Icon(option.icon, color: option.color, size: 22),
          ),
        );
      },
    );
  }
}

/// Bottom sheet wrapper around [CategoryIconGrid], opened by the pencil badge
/// on the Category Detail screen.
class CategoryIconPickerSheet extends StatelessWidget {
  final String selectedKey;

  const CategoryIconPickerSheet({super.key, required this.selectedKey});

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 10),
            decoration: BoxDecoration(
              color: AppTheme.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const Padding(
            padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text(
                'Icon & color',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: CategoryIconGrid(
              selectedKey: selectedKey,
              onSelected: (key) => Navigator.of(context).pop(key),
            ),
          ),
        ],
      ),
    );
  }
}

/// Paints a dashed rounded-rectangle border (used by "+ Add Subcategory").
class DashedBorderPainter extends CustomPainter {
  final Color color;
  final double radius;
  final double dash;
  final double gap;

  const DashedBorderPainter({
    required this.color,
    this.radius = 12,
    this.dash = 6,
    this.gap = 4,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final outline = Path()
      ..addRRect(
        RRect.fromRectAndRadius(
          Offset.zero & size,
          Radius.circular(radius),
        ),
      );

    final dashed = Path();
    for (final metric in outline.computeMetrics()) {
      double distance = 0;
      while (distance < metric.length) {
        final next = distance + dash;
        dashed.addPath(
          metric.extractPath(distance, next.clamp(0, metric.length)),
          Offset.zero,
        );
        distance = next + gap;
      }
    }

    canvas.drawPath(
      dashed,
      Paint()
        ..color = color
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2,
    );
  }

  @override
  bool shouldRepaint(covariant DashedBorderPainter old) =>
      old.color != color || old.radius != radius;
}
