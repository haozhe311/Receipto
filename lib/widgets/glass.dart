import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:receipto/constants/theme.dart';

/// Glassmorphism design-system primitives for the app-wide reskin.
///
/// Three tiers, deliberately different in cost:
///  - [GlassBackground] — the shared dark gradient + soft blurred blobs painted
///    once behind the whole app. The blobs are cheap radial-gradient glows (no
///    live blur) so scrolling content never pays a backdrop-blur cost for them.
///  - [HeroGlassCard] — standout, once-per-screen cards. Uses a real
///    [BackdropFilter] blur of whatever shows through.
///  - [ListGlassRow] — repeated rows in long lists. Same glass *look* but with
///    NO live blur, so a list of hundreds of rows stays smooth.
///
/// All three read as one family: semi-transparent white fill, a light 1px
/// border, rounded corners, and a subtle top highlight, over the dark backdrop.

// ── Shared backdrop ───────────────────────────────────────────────────────────

/// The app-wide backdrop: a deep indigo→navy gradient with a few soft colour
/// blobs. Wrapped once around the app root (via `MaterialApp.builder`); every
/// screen's Scaffold is transparent so this shows through.
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          // Gentle diagonal (~160°) — deep indigo top → deep navy bottom.
          begin: Alignment(-0.3, -1),
          end: Alignment(0.3, 1),
          colors: [
            AppTheme.bgGradientTop,
            AppTheme.bgGradientMid,
            AppTheme.bgGradientBottom,
          ],
          stops: [0.0, 0.5, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft blobs behind everything. RepaintBoundary keeps them off the
          // content's layer so list scrolling doesn't repaint them (the blur is
          // rasterised once, not per frame).
          const RepaintBoundary(
            child: Stack(
              children: [
                _Blob(
                  top: -40,
                  left: -60,
                  size: 220,
                  blur: 50,
                  color: AppTheme.blobPurple,
                  opacity: 0.35,
                ),
                _Blob(
                  top: 120,
                  right: -70,
                  size: 200,
                  blur: 55,
                  color: AppTheme.blobGold,
                  opacity: 0.25,
                ),
                _Blob(
                  bottom: 60,
                  left: -50,
                  size: 180,
                  blur: 50,
                  color: AppTheme.blobBlue,
                  opacity: 0.30,
                ),
              ],
            ),
          ),
          child,
        ],
      ),
    );
  }
}

/// A soft, blurred colour blob: a solid translucent circle run through a real
/// gaussian [ImageFilter]. Sits inside the backdrop's [RepaintBoundary], so the
/// blur is rasterised once and never recomputed during list scrolling.
class _Blob extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final double blur;
  final Color color;
  final double opacity;

  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.blur,
    required this.color,
    required this.opacity,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: IgnorePointer(
        child: ImageFiltered(
          imageFilter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color.withValues(alpha: opacity),
            ),
          ),
        ),
      ),
    );
  }
}

// ── Hero glass (real blur) ────────────────────────────────────────────────────

/// A standout glass card with a real backdrop blur. Use once (or a few times)
/// per screen — e.g. Net Worth, month summary. The blur is genuine, so it is
/// the more expensive tier; do not use it for repeated list rows.
class HeroGlassCard extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const HeroGlassCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.margin,
    this.borderRadius = 18,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    Widget content = Container(
      // Flat translucent fill + a defined border.
      decoration: BoxDecoration(
        borderRadius: radius,
        color: AppTheme.glassHeroFill,
        border: Border.all(color: AppTheme.glassBorder, width: 1),
      ),
      padding: padding,
      child: child,
    );

    if (onTap != null) {
      content = Stack(
        children: [
          content,
          Positioned.fill(
            child: Material(
              color: Colors.transparent,
              child: InkWell(borderRadius: radius, onTap: onTap),
            ),
          ),
        ],
      );
    }

    return Container(
      margin: margin,
      // Shadow lives on the outer box so the ClipRRect below doesn't clip it.
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppTheme.glassShadow,
            blurRadius: 32,
            offset: Offset(0, 8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: radius,
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
          child: content,
        ),
      ),
    );
  }
}

// ── List glass (no live blur) ─────────────────────────────────────────────────

/// A repeated list-row surface in the same glass family as [HeroGlassCard] but
/// WITHOUT a live [BackdropFilter] — so a long scrolling list pays no per-row
/// blur cost. Semi-transparent white fill, 1px light border, rounded corners,
/// subtle top highlight.
class ListGlassRow extends StatelessWidget {
  final Widget child;
  final EdgeInsetsGeometry padding;
  final EdgeInsetsGeometry? margin;
  final double borderRadius;
  final VoidCallback? onTap;

  const ListGlassRow({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(14),
    this.margin,
    this.borderRadius = 14,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);

    return Container(
      margin: margin,
      decoration: BoxDecoration(
        borderRadius: radius,
        color: AppTheme.glassRowFill,
        border: Border.all(color: AppTheme.glassBorderSoft, width: 1),
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Padding(padding: padding, child: child),
        ),
      ),
    );
  }
}
