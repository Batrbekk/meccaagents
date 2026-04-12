import 'package:flutter/material.dart';

class AppTheme {
  AppTheme._();

  // Core palette
  static const Color _background = Color(0xFF0D1117);
  static const Color _surface = Color(0xFF161B22);
  static const Color _card = Color(0xFF1C2333);
  static const Color _border = Color(0xFF30363D);
  static const Color _primary = Color(0xFF58A6FF);
  static const Color _primaryDark = Color(0xFF1F6FEB);
  static const Color _textPrimary = Color(0xFFE6EDF3);
  static const Color _textSecondary = Color(0xFF8B949E);
  static const Color _error = Color(0xFFF85149);
  static const Color _success = Color(0xFF3FB950);
  static const Color _warning = Color(0xFFD29922);

  static ThemeData get darkTheme {
    final colorScheme = ColorScheme.dark(
      primary: _primary,
      onPrimary: Colors.white,
      primaryContainer: _primaryDark,
      onPrimaryContainer: Colors.white,
      secondary: _primary,
      onSecondary: Colors.white,
      surface: _surface,
      onSurface: _textPrimary,
      error: _error,
      onError: Colors.white,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: colorScheme,
      scaffoldBackgroundColor: _background,
      canvasColor: _background,

      // AppBar
      appBarTheme: const AppBarTheme(
        backgroundColor: _surface,
        foregroundColor: _textPrimary,
        elevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),

      // Card
      cardTheme: CardThemeData(
        color: _card,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
          side: const BorderSide(color: _border, width: 1),
        ),
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      ),

      // Bottom Navigation
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: _surface,
        selectedItemColor: _primary,
        unselectedItemColor: _textSecondary,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),

      // Navigation Bar (Material 3)
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: _surface,
        indicatorColor: _primary.withValues(alpha: 0.15),
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const TextStyle(
              color: _primary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            );
          }
          return const TextStyle(
            color: _textSecondary,
            fontSize: 12,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return const IconThemeData(color: _primary, size: 24);
          }
          return const IconThemeData(color: _textSecondary, size: 24);
        }),
      ),

      // Divider
      dividerTheme: const DividerThemeData(
        color: _border,
        thickness: 1,
        space: 1,
      ),

      // Input fields
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: _surface,
        hintStyle: const TextStyle(color: _textSecondary),
        labelStyle: const TextStyle(color: _textSecondary),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _primary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(10),
          borderSide: const BorderSide(color: _error),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),

      // Elevated Button
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Text Button
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: _primary,
          textStyle: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),

      // Outlined Button
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: _textPrimary,
          side: const BorderSide(color: _border),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),

      // Floating Action Button
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        elevation: 2,
      ),

      // Dialog
      dialogTheme: DialogThemeData(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        titleTextStyle: const TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        contentTextStyle: const TextStyle(
          color: _textSecondary,
          fontSize: 14,
        ),
      ),

      // Bottom Sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: _card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
      ),

      // Chip
      chipTheme: ChipThemeData(
        backgroundColor: _surface,
        side: const BorderSide(color: _border),
        labelStyle: const TextStyle(color: _textPrimary, fontSize: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
      ),

      // ListTile
      listTileTheme: const ListTileThemeData(
        textColor: _textPrimary,
        iconColor: _textSecondary,
        contentPadding: EdgeInsets.symmetric(horizontal: 16),
      ),

      // Snackbar
      snackBarTheme: SnackBarThemeData(
        backgroundColor: _card,
        contentTextStyle: const TextStyle(color: _textPrimary),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(8),
        ),
        behavior: SnackBarBehavior.floating,
      ),

      // Text
      textTheme: const TextTheme(
        headlineLarge: TextStyle(
          color: _textPrimary,
          fontSize: 32,
          fontWeight: FontWeight.bold,
        ),
        headlineMedium: TextStyle(
          color: _textPrimary,
          fontSize: 24,
          fontWeight: FontWeight.w600,
        ),
        headlineSmall: TextStyle(
          color: _textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
        titleLarge: TextStyle(
          color: _textPrimary,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
        titleMedium: TextStyle(
          color: _textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w500,
        ),
        titleSmall: TextStyle(
          color: _textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w500,
        ),
        bodyLarge: TextStyle(color: _textPrimary, fontSize: 16),
        bodyMedium: TextStyle(color: _textPrimary, fontSize: 14),
        bodySmall: TextStyle(color: _textSecondary, fontSize: 12),
        labelLarge: TextStyle(
          color: _textPrimary,
          fontSize: 14,
          fontWeight: FontWeight.w600,
        ),
        labelMedium: TextStyle(color: _textSecondary, fontSize: 12),
        labelSmall: TextStyle(color: _textSecondary, fontSize: 11),
      ),

      // Icon
      iconTheme: const IconThemeData(
        color: _textSecondary,
        size: 24,
      ),

      // Progress indicators
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: _primary,
      ),

      // Switch
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) return _primary;
          return _textSecondary;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          if (states.contains(WidgetState.selected)) {
            return _primary.withValues(alpha: 0.3);
          }
          return _border;
        }),
      ),

      // Tooltip
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: _card,
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: _border),
        ),
        textStyle: const TextStyle(color: _textPrimary, fontSize: 12),
      ),
    );
  }

  // Convenience getters for custom colors not in the ColorScheme
  static Color get background => _background;
  static Color get surface => _surface;
  static Color get card => _card;
  static Color get border => _border;
  static Color get textSecondary => _textSecondary;
  static Color get success => _success;
  static Color get warning => _warning;
}
