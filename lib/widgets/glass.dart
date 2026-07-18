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
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.bgGradientTop,
            AppTheme.bgGradientMid,
            AppTheme.bgGradientBottom,
          ],
          stops: [0.0, 0.55, 1.0],
        ),
      ),
      child: Stack(
        children: [
          // Soft blobs behind everything. RepaintBoundary keeps them off the
          // content's layer so list scrolling doesn't repaint them.
          const RepaintBoundary(
            child: Stack(
              children: [
                _Blob(
                  top: -80,
                  left: -60,
                  size: 280,
                  color: AppTheme.blobPurple,
                  opacity: 0.40,
                ),
                _Blob(
                  top: 150,
                  right: -90,
                  size: 260,
                  color: AppTheme.blobGold,
                  opacity: 0.36,
                ),
                _Blob(
                  bottom: -70,
                  left: 0,
                  size: 280,
                  color: AppTheme.blobBlue,
                  opacity: 0.38,
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

/// A single soft radial-gradient glow standing in for a blurred blob — the
/// gaussian look without a per-frame [ImageFilter].
class _Blob extends StatelessWidget {
  final double? top;
  final double? left;
  final double? right;
  final double? bottom;
  final double size;
  final Color color;
  final double opacity;

  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
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
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: RadialGradient(
              // Hold the colour near full strength through the core, then fall
              // off — keeps each blob's purple/gold/blue identity instead of
              // homogenising into one flat tone.
              colors: [
                color.withValues(alpha: opacity),
                color.withValues(alpha: opacity * 0.7),
                color.withValues(alpha: 0),
              ],
              stops: const [0.0, 0.45, 1.0],
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
      // Fill (subtly brighter at the top) + a defined border.
      decoration: BoxDecoration(
        borderRadius: radius,
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.glassHeroTop, AppTheme.glassHeroFill],
        ),
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
        gradient: const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [AppTheme.glassRowTop, AppTheme.glassRowFill],
        ),
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

// ── Glass app bar (real blur) ─────────────────────────────────────────────────

/// A frosted-glass [AppBar]: translucent white fill over a real backdrop blur,
/// with no border. Drop-in for `Scaffold.appBar`. Adopted by screens in Phase 2
/// (Phase 1 already themes plain AppBars translucent).
class GlassAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Widget? title;
  final List<Widget>? actions;
  final Widget? leading;
  final bool centerTitle;
  final PreferredSizeWidget? bottom;

  const GlassAppBar({
    super.key,
    this.title,
    this.actions,
    this.leading,
    this.centerTitle = false,
    this.bottom,
  });

  @override
  Size get preferredSize =>
      Size.fromHeight(kToolbarHeight + (bottom?.preferredSize.height ?? 0));

  @override
  Widget build(BuildContext context) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: AppBar(
          title: title,
          actions: actions,
          leading: leading,
          centerTitle: centerTitle,
          bottom: bottom,
          backgroundColor: AppTheme.glassRowFill,
          elevation: 0,
          scrolledUnderElevation: 0,
          surfaceTintColor: Colors.transparent,
        ),
      ),
    );
  }
}
