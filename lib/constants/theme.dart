import 'package:flutter/material.dart';

/// Dark premium theme for Receipto.
///
/// Palette:
///   Background : #1A1A2E  (deep navy)
///   Surface    : #252540  (elevated panels / cards)
///   Gold accent: #F0C440  (primary interactive colour)
///   NavBar bg  : #141428  (darker than background)
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFF1A1A2E);
  static const Color surface = Color(0xFF252540);
  static const Color surfaceHigh = Color(0xFF2D2D50);
  static const Color navBar = Color(0xFF141428);
  static const Color gold = Color(0xFFF0C440);
  static const Color goldDark = Color(0xFF2D2D10);
  static const Color border = Color(0xFF35355A);
  static const Color textPrimary = Color(0xFFE8E8F0);
  static const Color textMuted = Color(0xFF8888AA);

  // ── Glassmorphism backdrop + surfaces ─────────────────────────────────────
  // The reskin paints a dark gradient with soft blurred blobs behind the whole
  // app (see [GlassBackground]); glass panels are semi-transparent white tints
  // that let that backdrop show through.

  /// Vertical background gradient stops (deep indigo → deep navy).
  static const Color bgGradientTop = Color(0xFF1A1440);
  static const Color bgGradientMid = Color(0xFF0D1B3D);
  static const Color bgGradientBottom = Color(0xFF14203A);

  /// Soft, blurred backdrop blob colours.
  static const Color blobPurple = Color(0xFF7A5CFF);
  static const Color blobGold = Color(0xFFF0C440);
  static const Color blobBlue = Color(0xFF4E9BFF);

  /// Glass surface tints (flat white over the dark backdrop).
  static const Color glassHeroFill = Color(0x1AFFFFFF); // ~0.10 — hero cards
  static const Color glassRowFill = Color(0x14FFFFFF); // ~0.08 — list rows
  static const Color glassBorder = Color(0x38FFFFFF); // ~0.22 — hero border
  static const Color glassBorderSoft = Color(0x2EFFFFFF); // ~0.18 — row border

  /// On-glass text colours — light, high-contrast against the dark backdrop.
  static const Color onGlass = Color(0xD9FFFFFF); // ~0.85 white — primary text
  static const Color onGlassMuted = Color(0x99FFFFFF); // ~0.60 white — labels
  static const Color onGlassFaint = Color(0x66FFFFFF); // ~0.40 white — hints
  /// Drop shadow beneath hero glass cards.
  static const Color glassShadow = Color(0x59140A3C); // rgba(20,10,60,0.35)

  static ThemeData get darkTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.dark,
      primary: gold,
      onPrimary: Color(0xFF1A1A00),
      primaryContainer: goldDark,
      onPrimaryContainer: gold,
      secondary: Color(0xFF9B8FFF),
      onSecondary: Colors.white,
      secondaryContainer: Color(0xFF2A2045),
      onSecondaryContainer: Color(0xFFCCC0FF),
      tertiary: Color(0xFF6DCEF5),
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFF1A2E40),
      onTertiaryContainer: Color(0xFFB0E8FF),
      error: Color(0xFFFF6B6B),
      onError: Colors.white,
      errorContainer: Color(0xFF3D1010),
      onErrorContainer: Color(0xFFFF9999),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceHigh,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: Color(0xFF2A2A4A),
      shadow: Colors.black,
      scrim: Colors.black,
      inverseSurface: textPrimary,
      onInverseSurface: background,
      inversePrimary: Color(0xFF7A6000),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      // Transparent so the global [GlassBackground] (gradient + blobs) shows
      // through every screen. The backdrop is painted once at the app root.
      scaffoldBackgroundColor: Colors.transparent,

      // AppBar — translucent glass floating over the backdrop. Screens that
      // adopt [GlassAppBar] additionally get a real frosted blur behind it.
      appBarTheme: const AppBarTheme(
        backgroundColor: glassRowFill,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          letterSpacing: 0.2,
        ),
        iconTheme: IconThemeData(color: textMuted),
        actionsIconTheme: IconThemeData(color: textMuted),
      ),

      // Cards
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border, width: 1),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: gold, width: 1.5),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B)),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: Color(0xFFFF6B6B), width: 1.5),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: TextStyle(color: textMuted.withAlpha(153)),
        prefixStyle: const TextStyle(color: textPrimary),
        suffixIconColor: textMuted,
        helperStyle: const TextStyle(color: textMuted, fontSize: 12),
      ),

      // Elevated buttons (gold, dark text)
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: const Color(0xFF1A1A00),
          disabledBackgroundColor: border,
          disabledForegroundColor: textMuted,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          elevation: 0,
        ),
      ),

      // Outlined buttons (gold border and text)
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          textStyle: const TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: gold),
      ),

      // FAB — rounded square, gold
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: Color(0xFF1A1A00),
        elevation: 2,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(14)),
        ),
      ),

      // NavigationBar — transparent; the bar is wrapped in a frosted glass
      // container at the app root (see AppShell) so the backdrop blurs behind it.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: goldDark,
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: gold);
          }
          return const IconThemeData(color: textMuted);
        }),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: gold,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: goldDark,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: border),
        ),
      ),

      // Bottom sheets
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Dividers
      dividerTheme: const DividerThemeData(
        color: border,
        thickness: 1,
        space: 1,
      ),

      // List tiles
      listTileTheme: const ListTileThemeData(
        textColor: textPrimary,
        iconColor: textMuted,
      ),

      // SegmentedButton
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: surface,
          foregroundColor: textMuted,
          selectedForegroundColor: gold,
          selectedBackgroundColor: goldDark,
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),

      // ExpansionTile
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: textMuted,
        collapsedIconColor: textMuted,
        textColor: textPrimary,
        collapsedTextColor: textPrimary,
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceHigh,
        contentTextStyle: const TextStyle(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        behavior: SnackBarBehavior.floating,
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall: TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary),
        headlineMedium: TextStyle(
          color: textPrimary,
          fontWeight: FontWeight.bold,
        ),
        headlineSmall: TextStyle(color: textPrimary),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w500),
        bodyLarge: TextStyle(color: textPrimary),
        bodyMedium: TextStyle(color: textPrimary),
        bodySmall: TextStyle(color: textMuted),
        labelLarge: TextStyle(color: textPrimary),
        labelMedium: TextStyle(color: textMuted),
        labelSmall: TextStyle(color: textMuted),
      ),

      // Icon theme
      iconTheme: const IconThemeData(color: textMuted),
      primaryIconTheme: const IconThemeData(color: gold),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(color: gold),
    );
  }
}
