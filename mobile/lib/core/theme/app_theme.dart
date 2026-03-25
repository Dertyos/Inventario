import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  AppTheme._();

  // Brand colors
  static const _primarySeed = Color(0xFF1A73E8);
  static const _secondarySeed = Color(0xFF34A853);
  static const _tertiarySeed = Color(0xFFFBAC44);
  static const _errorSeed = Color(0xFFEA4335);

  static final light = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primarySeed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      error: _errorSeed,
      brightness: Brightness.light,
      surface: const Color(0xFFF8FAFB),
    ),
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade200),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: Colors.grey.shade50,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey.shade300),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _primarySeed, width: 2),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: _errorSeed),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
    ),
    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
    ),
    dividerTheme: DividerThemeData(
      space: 1,
      thickness: 1,
      color: Colors.grey.shade200,
    ),
  );

  static final dark = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: ColorScheme.fromSeed(
      seedColor: _primarySeed,
      secondary: _secondarySeed,
      tertiary: _tertiarySeed,
      error: _errorSeed,
      brightness: Brightness.dark,
    ),
    textTheme: _textTheme,
    appBarTheme: const AppBarTheme(
      centerTitle: false,
      elevation: 0,
      scrolledUnderElevation: 1,
    ),
    cardTheme: CardThemeData(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: BorderSide(color: Colors.grey.shade800),
      ),
      clipBehavior: Clip.antiAlias,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
        textStyle: const TextStyle(
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(double.infinity, 52),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      elevation: 2,
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dialogTheme: DialogThemeData(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
    ),
    bottomSheetTheme: const BottomSheetThemeData(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      showDragHandle: true,
    ),
  );

  static final _textTheme = GoogleFonts.interTextTheme().copyWith(
    displayLarge: GoogleFonts.inter(fontWeight: FontWeight.w700),
    displayMedium: GoogleFonts.inter(fontWeight: FontWeight.w700),
    displaySmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
    headlineLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    headlineMedium: GoogleFonts.inter(fontWeight: FontWeight.w600),
    headlineSmall: GoogleFonts.inter(fontWeight: FontWeight.w600),
    titleLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    titleMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
    titleSmall: GoogleFonts.inter(fontWeight: FontWeight.w500),
    bodyLarge: GoogleFonts.inter(),
    bodyMedium: GoogleFonts.inter(),
    bodySmall: GoogleFonts.inter(),
    labelLarge: GoogleFonts.inter(fontWeight: FontWeight.w600),
    labelMedium: GoogleFonts.inter(fontWeight: FontWeight.w500),
    labelSmall: GoogleFonts.inter(fontWeight: FontWeight.w500),
  );
}

// Spacing constants
class AppSpacing {
  AppSpacing._();
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
  static const xxl = 48.0;
}

/// Semantic status colors for consistent use across the app.
/// Use these instead of hardcoding Colors.green/orange/red.
class AppColors {
  AppColors._();
  // Status
  static const success = Color(0xFF34A853);
  static const warning = Color(0xFFFBAC44);
  static const danger = Color(0xFFEA4335);
  static const info = Color(0xFF1A73E8);

  // Status with opacity for backgrounds
  static Color successBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? success.withValues(alpha: 0.15)
          : success.withValues(alpha: 0.1);
  static Color warningBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? warning.withValues(alpha: 0.15)
          : warning.withValues(alpha: 0.1);
  static Color dangerBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? danger.withValues(alpha: 0.15)
          : danger.withValues(alpha: 0.1);
  static Color infoBg(BuildContext context) =>
      Theme.of(context).brightness == Brightness.dark
          ? info.withValues(alpha: 0.15)
          : info.withValues(alpha: 0.1);
}

/// Standard dimensions to eliminate magic numbers.
class AppDimensions {
  AppDimensions._();
  // Avatar / leading icon containers
  static const avatarSm = 36.0;
  static const avatarMd = 40.0;
  static const avatarLg = 44.0;
  static const iconSizeSm = 16.0;
  static const iconSizeMd = 20.0;
  static const iconSizeLg = 24.0;
  // Border radius
  static const radiusXs = 6.0;
  static const radiusSm = 8.0;
  static const radiusMd = 12.0;
  static const radiusLg = 16.0;
  static const radiusXl = 20.0;
  static const radiusFull = 24.0;
  // Touch targets (WCAG)
  static const touchTarget = 48.0;
  // Button height
  static const buttonHeight = 52.0;
}

/// Shared shadow definitions.
class AppShadows {
  AppShadows._();
  static List<BoxShadow> sm(BuildContext context) => [
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.05),
          blurRadius: 4,
          offset: const Offset(0, 1),
        ),
      ];
  static List<BoxShadow> md(BuildContext context) => [
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.08),
          blurRadius: 8,
          offset: const Offset(0, 2),
        ),
      ];
  static List<BoxShadow> lg(BuildContext context) => [
        BoxShadow(
          color: Theme.of(context).shadowColor.withValues(alpha: 0.12),
          blurRadius: 16,
          offset: const Offset(0, 4),
        ),
      ];
}

/// Shared animation durations and curves.
class AppAnimations {
  AppAnimations._();
  static const fast = Duration(milliseconds: 150);
  static const normal = Duration(milliseconds: 300);
  static const slow = Duration(milliseconds: 500);
  static const defaultCurve = Curves.easeInOut;
  static const bounceCurve = Curves.elasticOut;
}
