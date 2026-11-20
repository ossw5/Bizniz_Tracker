import 'package:flutter/material.dart';

class AppColors {
  static bool _darkMode = false;

  static set darkMode(bool value) => _darkMode = value;

  static const Color forestGreen = Color(0xFF2F6E67);
  static const Color freshGreen = Color(0xFF4F8E82);
  static const Color gold = Color(0xFFE8B936);
  static Color get background =>
      _darkMode ? const Color(0xFF121A19) : const Color(0xFFF4F6F4);
  static Color get white =>
      _darkMode ? const Color(0xFF202A28) : const Color(0xFFFFFFFF);
  static Color get charcoal =>
      _darkMode ? const Color(0xFFE8EFED) : const Color(0xFF26312F);
  static Color get grey =>
      _darkMode ? const Color(0xFFADB9B6) : const Color(0xFF697572);
  static const Color warning = Color(0xFFE0AE36);
  static const Color error = Color(0xFFE53935);
  static Color get softGreen =>
      _darkMode ? const Color(0xFF2B3D39) : const Color(0xFFE5F0ED);
  static const Color softWarning = Color(0xFFFFF4D6);
  static const Color softRed = Color(0xFFFFEBEE);
}

class AppTheme {
  static ThemeData buildTheme({Brightness brightness = Brightness.light}) {
    final isDark = brightness == Brightness.dark;
    final surface = isDark ? const Color(0xFF202A28) : const Color(0xFFFFFFFF);
    final foreground = isDark
        ? const Color(0xFFE8EFED)
        : const Color(0xFF26312F);
    final outline = isDark ? const Color(0xFF465450) : const Color(0xFFDCE3E0);
    final base = ThemeData(
      useMaterial3: true,
      fontFamily: 'Roboto',
      brightness: brightness,
      scaffoldBackgroundColor: AppColors.background,
      colorScheme:
          ColorScheme.fromSeed(
            seedColor: AppColors.forestGreen,
            brightness: brightness,
          ).copyWith(
            primary: AppColors.forestGreen,
            onPrimary: Colors.white,
            secondary: AppColors.gold,
            onSecondary: const Color(0xFF26312F),
            surface: surface,
            onSurface: foreground,
            outline: outline,
          ),
    );

    return base.copyWith(
      appBarTheme: AppBarTheme(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: base.textTheme.titleLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 1,
        margin: EdgeInsets.zero,
        shadowColor: Colors.black.withValues(alpha: isDark ? 0.18 : 0.06),
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.forestGreen,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.forestGreen,
          side: BorderSide(color: outline),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: AppColors.forestGreen,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.forestGreen,
        foregroundColor: Colors.white,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: AppColors.softGreen,
        elevation: 2,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return TextStyle(
            color: selected ? AppColors.forestGreen : AppColors.grey,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          final selected = states.contains(WidgetState.selected);
          return IconThemeData(
            color: selected ? AppColors.forestGreen : AppColors.grey,
          );
        }),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: AppColors.forestGreen,
        unselectedItemColor: AppColors.grey,
        type: BottomNavigationBarType.fixed,
        elevation: 4,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide(color: outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(
            color: AppColors.forestGreen,
            width: 1.5,
          ),
        ),
      ),
      tabBarTheme: const TabBarThemeData(
        labelColor: Colors.white,
        unselectedLabelColor: Color(0xFFD7E5E1),
        indicatorColor: AppColors.gold,
        indicatorSize: TabBarIndicatorSize.label,
      ),
      checkboxTheme: CheckboxThemeData(
        fillColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.forestGreen
              : null;
        }),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.forestGreen
              : null;
        }),
        trackColor: WidgetStateProperty.resolveWith((states) {
          return states.contains(WidgetState.selected)
              ? AppColors.softGreen
              : null;
        }),
      ),
      dividerTheme: DividerThemeData(color: outline, thickness: 1, space: 1),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: isDark
            ? const Color(0xFF303A38)
            : const Color(0xFF26312F),
        contentTextStyle: const TextStyle(color: Colors.white),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      textTheme: base.textTheme.copyWith(
        headlineSmall: TextStyle(
          fontWeight: FontWeight.w700,
          color: foreground,
        ),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: foreground),
        bodyMedium: TextStyle(color: foreground),
        bodySmall: TextStyle(color: AppColors.grey),
      ),
    );
  }
}
