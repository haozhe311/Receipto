import 'package:flutter/material.dart';
import 'package:receipto/constants/category_icons.dart';
import 'package:receipto/constants/theme.dart';

/// A grid of preset icon swatches (each a fixed icon + colour pairing). The
/// selected swatch is marked with a gold ring. Shared by the Add Category
/// dialog and the Category Detail screen so selection looks identical in both,
/// and is the single place icons are chosen.
///
/// Deliberately a [Wrap] rather than a GridView: the preset list is small and
/// fixed, so it needs no lazy scrolling — and a scrolling viewport cannot
/// report intrinsic dimensions, which throws inside an AlertDialog (whose
/// IntrinsicWidth queries its children's intrinsic height).
class CategoryIconGrid extends StatelessWidget {
  final String selectedKey;
  final ValueChanged<String> onSelected;
  final double swatchSize;

  const CategoryIconGrid({
    super.key,
    required this.selectedKey,
    required this.onSelected,
    this.swatchSize = 46,
  });

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 12,
      runSpacing: 12,
      children: [
        for (final option in CategoryIcons.presets)
          GestureDetector(
            onTap: () => onSelected(option.key),
            child: Container(
              width: swatchSize,
              height: swatchSize,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: option.color.withAlpha(38),
                border: Border.all(
                  color: option.key == selectedKey
                      ? AppTheme.gold
                      : AppTheme.border,
                  width: option.key == selectedKey ? 2 : 1,
                ),
              ),
              child: Icon(option.icon, color: option.color, size: 22),
            ),
          ),
      ],
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
