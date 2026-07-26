import 'dart:ui' show ImageFilter;

import 'package:flutter/material.dart';
import 'package:receipto/constants/theme.dart';

/// Clean "card" design-system primitives (ParkingLah-style light look).
///
/// The class names are kept from the previous (glass) design system so every
/// existing call site keeps working — they now render as flat white cards with
/// soft shadows on a light page instead of translucent glass.

// ── Page background ───────────────────────────────────────────────────────────

/// The flat light page background painted behind every screen. Wrapped once per
/// route (via [GlassPageTransitionsBuilder]) so route pushes stay opaque.
class GlassBackground extends StatelessWidget {
  final Widget child;

  const GlassBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ColoredBox(color: AppTheme.background, child: child);
  }
}

// ── Hero card (standout) ──────────────────────────────────────────────────────

/// A standout white card with a soft shadow — e.g. Net Worth, month summary.
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
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppTheme.glassShadow,
            blurRadius: 20,
            offset: Offset(0, 6),
          ),
        ],
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

// ── List row (repeated content) ───────────────────────────────────────────────

/// A white row/card for repeated list content — same look as [HeroGlassCard]
/// with a lighter shadow. Cheap to stack many of (plain shadow, no blur).
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
    this.borderRadius = 16,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(borderRadius);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: AppTheme.surface,
        borderRadius: radius,
        boxShadow: const [
          BoxShadow(
            color: AppTheme.glassShadow,
            blurRadius: 12,
            offset: Offset(0, 3),
          ),
        ],
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

// ── Modal sheet background ────────────────────────────────────────────────────

/// White background for a modal bottom sheet, with rounded top corners and a
/// soft lift shadow. The bottom-sheet theme is transparent so this is what the
/// user actually sees.
class GlassSheetBackground extends StatelessWidget {
  final Widget child;

  const GlassSheetBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          color: AppTheme.surface,
          boxShadow: [
            BoxShadow(
              color: AppTheme.glassShadow,
              blurRadius: 24,
              offset: Offset(0, -4),
            ),
          ],
        ),
        child: child,
      ),
    );
  }
}

/// Frosted translucent bottom-sheet background matching the floating nav pill:
/// a real backdrop blur of the content behind plus a translucent white fill and
/// a hairline top highlight. Pair with `backgroundColor: Colors.transparent`
/// (and ideally a light `barrierColor`) on `showModalBottomSheet`.
class FrostedSheetBackground extends StatelessWidget {
  final Widget child;

  const FrostedSheetBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
        child: DecoratedBox(
          decoration: const BoxDecoration(
            color: AppTheme.navGlassFill,
            border: Border(
              top: BorderSide(color: Color(0x99FFFFFF), width: 1),
            ),
          ),
          child: child,
        ),
      ),
    );
  }
}

// ── Opaque page transitions ───────────────────────────────────────────────────

/// Gives every pushed route its own opaque [GlassBackground] before applying the
/// normal platform page transition, so a route transition can't reveal the page
/// underneath through a transparent scaffold.
class GlassPageTransitionsBuilder extends PageTransitionsBuilder {
  const GlassPageTransitionsBuilder();

  @override
  Widget buildTransitions<T>(
    PageRoute<T> route,
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
    Widget child,
  ) {
    return const ZoomPageTransitionsBuilder().buildTransitions(
      route,
      context,
      animation,
      secondaryAnimation,
      GlassBackground(child: child),
    );
  }
}
