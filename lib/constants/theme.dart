import 'package:flutter/material.dart';

/// Light, clean theme for Receipto (ParkingLah-style).
///
/// Palette:
///   Page bg   : #EBEEF3  (soft light grey-blue)
///   Card      : #FFFFFF  (white, soft shadow)
///   Primary   : #22A7F0  (bright blue — buttons, links, selected)
///   Accent    : #FFB81C  (warm yellow — brand / steppers)
///   Positive  : #22C55E  (green — available / money in)
///   Danger    : #EF4444  (red)
///   Heading   : #13233B  (near-black navy)
///   Muted      : #64748B  (slate grey)
///
/// Note: the historical accent constant is still named [gold] (used across many
/// screens) but now holds the primary BLUE, so those usages recolour for free.
class AppTheme {
  AppTheme._();

  static const Color background = Color(0xFFEBEEF3);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceHigh = Color(0xFFEEF1F5);
  static const Color navBar = Color(0xFFFFFFFF);

  /// Primary interactive colour (blue). Kept named `gold` for source compat.
  static const Color gold = Color(0xFF22A7F0);

  /// Selected / primary-container tint (light blue).
  static const Color goldDark = Color(0xFFE1F1FD);

  static const Color border = Color(0xFFE4E8EE);
  static const Color textPrimary = Color(0xFF13233B);
  static const Color textMuted = Color(0xFF64748B);

  /// Extra semantic colours.
  static const Color positive = Color(0xFF22C55E);
  static const Color danger = Color(0xFFEF4444);
  static const Color accentYellow = Color(0xFFFFB81C);

  // ── Background (kept for the shared background widget) ─────────────────────
  // The reskin uses a flat light page colour; these were the old gradient/blob
  // colours and are no longer painted.
  static const Color bgGradientTop = background;
  static const Color bgGradientMid = background;
  static const Color bgGradientBottom = background;
  static const Color blobPurple = background;
  static const Color blobGold = background;
  static const Color blobBlue = background;

  // ── Card / surface tokens (used by the shared card widgets) ───────────────
  static const Color glassHeroFill = surface; // white hero cards
  static const Color glassRowFill = surface; // white list rows
  static const Color glassBorder = Color(0xFFE7EBF0);
  static const Color glassBorderSoft = Color(0xFFEDEFF3);

  /// On-card text colours.
  static const Color onGlass = textPrimary; // headings on white
  static const Color onGlassMuted = textMuted; // labels
  static const Color onGlassFaint = Color(0xFF94A3B8); // hints / chevrons

  /// Modal bottom-sheet fill (white).
  static const Color glassSheetFill = surface;

  /// Soft drop shadow under cards.
  static const Color glassShadow = Color(0x14101B2D); // ~8% navy

  static ThemeData get darkTheme => lightTheme;

  static ThemeData get lightTheme {
    const colorScheme = ColorScheme(
      brightness: Brightness.light,
      primary: gold,
      onPrimary: Colors.white,
      primaryContainer: goldDark,
      onPrimaryContainer: Color(0xFF0B4A73),
      secondary: accentYellow,
      onSecondary: Color(0xFF3A2A00),
      secondaryContainer: Color(0xFFFFF2D2),
      onSecondaryContainer: Color(0xFF5A4300),
      tertiary: positive,
      onTertiary: Colors.white,
      tertiaryContainer: Color(0xFFDCF7E6),
      onTertiaryContainer: Color(0xFF0C5A2C),
      error: danger,
      onError: Colors.white,
      errorContainer: Color(0xFFFEE2E2),
      onErrorContainer: Color(0xFF8A1C1C),
      surface: surface,
      onSurface: textPrimary,
      surfaceContainerHighest: surfaceHigh,
      onSurfaceVariant: textMuted,
      outline: border,
      outlineVariant: Color(0xFFEDF0F4),
      shadow: Color(0x33101B2D),
      scrim: Color(0x66101B2D),
      inverseSurface: textPrimary,
      onInverseSurface: Colors.white,
      inversePrimary: Color(0xFF9AD6FA),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: Colors.transparent, // GlassBackground paints bg

      // AppBar — sits on the light page, dark title, no shadow.
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: TextStyle(
          color: textPrimary,
          fontSize: 22,
          fontWeight: FontWeight.w800,
          letterSpacing: -0.2,
        ),
        iconTheme: IconThemeData(color: textPrimary),
        actionsIconTheme: IconThemeData(color: textPrimary),
      ),

      // Cards — white, rounded, soft shadow.
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: glassShadow,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
        margin: EdgeInsets.zero,
      ),

      // Input fields — light grey fill, rounded, blue focus.
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceHigh,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: gold, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: danger, width: 1.6),
        ),
        labelStyle: const TextStyle(color: textMuted),
        hintStyle: const TextStyle(color: Color(0xFF9AA6B5)),
        prefixStyle: const TextStyle(color: textPrimary),
        suffixIconColor: textMuted,
        prefixIconColor: textMuted,
        helperStyle: const TextStyle(color: textMuted, fontSize: 12),
      ),

      // Elevated buttons — blue fill, white text, pill-ish.
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: gold,
          foregroundColor: Colors.white,
          disabledBackgroundColor: const Color(0xFFDCE1E8),
          disabledForegroundColor: const Color(0xFF9AA6B5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          elevation: 0,
        ),
      ),

      // Outlined buttons — blue border and text.
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: gold,
          side: const BorderSide(color: gold, width: 1.4),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 15),
          textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
      ),

      // Text buttons
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: gold,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),

      // FAB — blue, rounded.
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: gold,
        foregroundColor: Colors.white,
        elevation: 3,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(18)),
        ),
      ),

      // NavigationBar — light; the app root wraps the bar in a floating pill.
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
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
              fontWeight: FontWeight.w700,
            );
          }
          return const TextStyle(color: textMuted, fontSize: 12);
        }),
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),

      // Chips
      chipTheme: ChipThemeData(
        backgroundColor: surfaceHigh,
        selectedColor: goldDark,
        side: const BorderSide(color: border),
        labelStyle: const TextStyle(color: textPrimary, fontSize: 13),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),

      // Dialogs
      dialogTheme: DialogThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
      ),

      // Bottom sheets — transparent so sheets paint their own white surface.
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: Colors.transparent,
        modalBackgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
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

      // SegmentedButton — light track, white selected segment, dark text.
      segmentedButtonTheme: SegmentedButtonThemeData(
        style: SegmentedButton.styleFrom(
          backgroundColor: surfaceHigh,
          foregroundColor: textMuted,
          selectedForegroundColor: textPrimary,
          selectedBackgroundColor: surface,
          side: const BorderSide(color: border),
          textStyle: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
        ),
      ),

      // ExpansionTile
      expansionTileTheme: const ExpansionTileThemeData(
        iconColor: textMuted,
        collapsedIconColor: textMuted,
        textColor: textPrimary,
        collapsedTextColor: textPrimary,
      ),

      // Snackbar — dark navy for contrast.
      snackBarTheme: SnackBarThemeData(
        backgroundColor: textPrimary,
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),

      // Text theme
      textTheme: const TextTheme(
        displayLarge: TextStyle(color: textPrimary),
        displayMedium: TextStyle(color: textPrimary),
        displaySmall: TextStyle(color: textPrimary),
        headlineLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        headlineMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w800),
        headlineSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleLarge: TextStyle(color: textPrimary, fontWeight: FontWeight.w700),
        titleMedium: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
        titleSmall: TextStyle(color: textPrimary, fontWeight: FontWeight.w600),
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
