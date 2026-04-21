import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // ---------------------------------------------------------------------------
  // Design-token palette (Pencil Dev — light theme)
  // ---------------------------------------------------------------------------

  // Surfaces
  static const Color surfacePrimary = Color(0xFFFFFFFF);
  static const Color surfaceSecondary = Color(0xFFFDE2D9);
  static const Color scaffoldBg = Color(0xFFF3F4F6);

  // Foregrounds
  static const Color foregroundPrimary = Color(0xFF1A1A1A);
  static const Color foregroundSecondary = Color(0xFF4B5563);
  static const Color foregroundTertiary = Color(0xFF9CA3AF);
  static const Color foregroundInverse = Color(0xFFFFFFFF);

  // Accent / Brand
  static const Color accentPrimary = Color(0xFFFF000B);
  static const Color accentPrimaryLight = Color(0xFFFFE5E6); // tinted bg

  // Borders
  static const Color borderDefault = Color(0xFFE5E7EB);
  static const Color borderLight = Color(0xFFF3F4F6);
  static const Color borderInput = Color(0xFFD1D5DB);

  // Semantic
  static const Color error = Color(0xFFDC2626);
  static const Color errorBg = Color(0xFFFEE2E2);
  static const Color success = Color(0xFF16A34A);
  static const Color successBg = Color(0xFFDCFCE7);
  static const Color warning = Color(0xFF92400E);
  static const Color warningBg = Color(0xFFFEF3C7);

  // Radii (design tokens)
  static const double radiusSm = 4;
  static const double radiusMd = 6;
  static const double radiusLg = 16;
  static const double radiusXl = 20;
  static const double radiusPill = 36;

  // Heights
  static const double inputHeight = 48;
  static const double buttonHeight = 48;
  static const double tabBarHeight = 62;

  // ---------------------------------------------------------------------------
  // Typography helpers
  // ---------------------------------------------------------------------------

  /// Anton — used for headings / display text.
  static TextStyle _anton({
    double fontSize = 28,
    FontWeight fontWeight = FontWeight.w400,
    Color color = foregroundPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.anton(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  /// Inter — body / UI text (fallback for Geist which is not on Google Fonts).
  static TextStyle _inter({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.w400,
    Color color = foregroundPrimary,
    double? height,
    double? letterSpacing,
  }) {
    return GoogleFonts.inter(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height,
      letterSpacing: letterSpacing,
    );
  }

  // ---------------------------------------------------------------------------
  // Theme
  // ---------------------------------------------------------------------------

  static ThemeData get lightTheme {
    final colorScheme = ColorScheme.light(
      primary: accentPrimary,
      onPrimary: foregroundInverse,
      primaryContainer: accentPrimaryLight,
      onPrimaryContainer: accentPrimary,
      secondary: accentPrimary,
      onSecondary: foregroundInverse,
      surface: surfacePrimary,
      onSurface: foregroundPrimary,
      error: error,
      onError: foregroundInverse,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: scaffoldBg,
      canvasColor: surfacePrimary,
      fontFamily: GoogleFonts.inter().fontFamily,

      // ------- AppBar -------
      appBarTheme: AppBarTheme(
        backgroundColor: surfacePrimary,
        foregroundColor: foregroundPrimary,
        elevation: 0,
        scrolledUnderElevation: 0.5,
        centerTitle: false,
        titleTextStyle: _inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foregroundPrimary,
        ),
      ),

      // ------- Card -------
      cardTheme: CardThemeData(
        color: surfacePrimary,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderDefault, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // ------- Bottom Navigation -------
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surfacePrimary,
        selectedItemColor: accentPrimary,
        unselectedItemColor: foregroundTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // ------- Navigation Bar (Material 3) -------
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surfacePrimary,
        indicatorColor: accentPrimaryLight,
        surfaceTintColor: Colors.transparent,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _inter(
              color: accentPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return _inter(
            color: foregroundTertiary,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: accentPrimary, size: 24);
          }
          return const IconThemeData(color: foregroundTertiary, size: 24);
        }),
      ),

      // ------- Divider -------
      dividerTheme: const DividerThemeData(
        color: borderDefault,
        thickness: 1,
        space: 1,
      ),

      // ------- Input Fields -------
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfacePrimary,
        hintStyle: _inter(color: foregroundTertiary),
        labelStyle: _inter(color: foregroundSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderInput),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: borderInput),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: accentPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(radiusSm),
          borderSide: const BorderSide(color: error, width: 2),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: (inputHeight - 20) / 2, // vertically center text
        ),
      ),

      // ------- Elevated Button -------
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: accentPrimary,
          foregroundColor: foregroundInverse,
          elevation: 0,
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
          textStyle: _inter(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: foregroundInverse,
          ),
        ),
      ),

      // ------- Text Button -------
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: accentPrimary,
          textStyle: _inter(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // ------- Outlined Button -------
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: foregroundPrimary,
          side: const BorderSide(color: borderDefault),
          minimumSize: const Size(0, buttonHeight),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(radiusSm),
          ),
        ),
      ),

      // ------- FAB -------
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: accentPrimary,
        foregroundColor: foregroundInverse,
        elevation: 2,
      ),

      // ------- Dialog -------
      dialogTheme: DialogThemeData(
        backgroundColor: surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusLg),
        ),
        titleTextStyle: _inter(
          color: foregroundPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: _inter(
          color: foregroundSecondary,
          fontSize: 14,
        ),
      ),

      // ------- Bottom Sheet -------
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // ------- Chip -------
      chipTheme: ChipThemeData(
        backgroundColor: surfaceSecondary,
        side: const BorderSide(color: borderDefault),
        labelStyle: _inter(color: foregroundPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
      ),

      // ------- ListTile -------
      listTileTheme: const ListTileThemeData(
        textColor: foregroundPrimary,
        iconColor: foregroundSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),

      // ------- SnackBar -------
      snackBarTheme: SnackBarThemeData(
        backgroundColor: foregroundPrimary,
        contentTextStyle: _inter(color: foregroundInverse),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusSm),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // ------- Text Theme -------
      textTheme: TextTheme(
        // Display — Anton headings
        displayLarge: _anton(fontSize: 32, color: foregroundPrimary),
        displayMedium: _anton(fontSize: 28, color: foregroundPrimary),
        displaySmall: _anton(fontSize: 24, color: foregroundPrimary),

        // Headlines — Anton
        headlineLarge: _anton(
          fontSize: 28,
          color: foregroundPrimary,
          letterSpacing: 0.2,
        ),
        headlineMedium: _anton(
          fontSize: 22,
          color: foregroundPrimary,
          letterSpacing: 0.15,
        ),
        headlineSmall: _anton(
          fontSize: 16,
          color: foregroundPrimary,
        ),

        // Titles — Inter semibold
        titleLarge: _inter(
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: foregroundPrimary,
        ),
        titleMedium: _inter(
          fontSize: 16,
          fontWeight: FontWeight.w500,
          color: foregroundPrimary,
        ),
        titleSmall: _inter(
          fontSize: 14,
          fontWeight: FontWeight.w500,
          color: foregroundPrimary,
        ),

        // Body — Inter normal
        bodyLarge: _inter(fontSize: 16, color: foregroundPrimary),
        bodyMedium: _inter(fontSize: 14, color: foregroundPrimary),
        bodySmall: _inter(fontSize: 12, color: foregroundSecondary),

        // Labels — Inter
        labelLarge: _inter(
          fontSize: 14,
          fontWeight: FontWeight.w600,
          color: foregroundPrimary,
        ),
        labelMedium: _inter(
          fontSize: 12,
          fontWeight: FontWeight.w500,
          color: foregroundSecondary,
        ),
        labelSmall: _inter(
          fontSize: 11,
          fontWeight: FontWeight.w500,
          color: foregroundSecondary,
        ),
      ),

      // ------- Icon -------
      iconTheme: const IconThemeData(
        color: foregroundSecondary,
        size: 24,
      ),

      // ------- Progress Indicators -------
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: accentPrimary,
      ),

      // ------- Switch -------
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return accentPrimary;
          return foregroundTertiary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return accentPrimary.withValues(alpha: 0.3);
          }
          return borderDefault;
        }),
      ),

      // ------- Tooltip -------
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: foregroundPrimary,
          borderRadius: BorderRadius.circular(6),
        ),
        textStyle: _inter(color: foregroundInverse, fontSize: 12),
      ),

      // ------- TabBar -------
      tabBarTheme: TabBarThemeData(
        labelColor: foregroundInverse,
        unselectedLabelColor: foregroundSecondary,
        indicatorColor: accentPrimary,
        labelStyle: _inter(fontSize: 14, fontWeight: FontWeight.w600),
        unselectedLabelStyle: _inter(fontSize: 14),
      ),

      // ------- PopupMenu -------
      popupMenuTheme: PopupMenuThemeData(
        color: surfacePrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: borderDefault),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Convenience getters for custom tokens not in ColorScheme
  // (preserves the same API the screens already reference)
  // ---------------------------------------------------------------------------
  static Color get background => scaffoldBg;
  static Color get surface => surfacePrimary;
  static Color get card => surfacePrimary;
  static Color get border => borderDefault;
  static Color get textSecondary => foregroundSecondary;

  // Re-export semantic colours so existing call sites still compile.
  static const Color successColor = success;
  static const Color warningColor = warning;

  // ---------------------------------------------------------------------------
  // Status badge helpers (design spec)
  // ---------------------------------------------------------------------------
  static const Map<String, ({Color background, Color foreground})>
      statusBadgeColors = {
    'success': (background: successBg, foreground: success),
    'warning': (background: warningBg, foreground: warning),
    'error': (background: errorBg, foreground: error),
  };
}
