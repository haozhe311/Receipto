import 'package:flutter/material.dart';

/// Wraps a tappable child with an iOS/Xiaomi-style press effect: the child
/// quickly shrinks (and dims slightly) while held, then springs back on
/// release. Fires [onTap] on release.
///
/// Use it around any entry point — buttons, cards, list rows — to give a
/// consistent, tactile press response across the app.
class PressableScale extends StatefulWidget {
  final Widget child;
  final VoidCallback? onTap;

  /// How small the child gets while pressed (1.0 = no shrink).
  final double pressedScale;

  /// Opacity while pressed.
  final double pressedOpacity;

  const PressableScale({
    super.key,
    required this.child,
    required this.onTap,
    this.pressedScale = 0.9,
    this.pressedOpacity = 0.75,
  });

  @override
  State<PressableScale> createState() => _PressableScaleState();
}

class _PressableScaleState extends State<PressableScale> {
  bool _pressed = false;

  void _set(bool v) {
    if (widget.onTap == null) return;
    if (_pressed != v) setState(() => _pressed = v);
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _set(true),
      onTapUp: (_) => _set(false),
      onTapCancel: () => _set(false),
      onTap: widget.onTap,
      child: AnimatedScale(
        scale: _pressed ? widget.pressedScale : 1.0,
        // Shrink fast on press, spring back with a gentle overshoot.
        duration: Duration(milliseconds: _pressed ? 110 : 260),
        curve: _pressed ? Curves.easeOut : Curves.easeOutBack,
        child: AnimatedOpacity(
          opacity: _pressed ? widget.pressedOpacity : 1.0,
          duration: const Duration(milliseconds: 110),
          child: widget.child,
        ),
      ),
    );
  }
}
