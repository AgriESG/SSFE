import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:io' show Platform;

// ---------------------------------------------------------------------------
// Fonts.
//
// Bundled as local assets (assets/fonts/) rather than fetched at runtime via
// google_fonts. A font pulled over the network renders in the platform
// fallback (San Francisco / Roboto) until the download completes, and on a
// cold start that races with the API's own wake-up call — different pieces
// of text can and did finish loading at different times, which is why the
// app read as mismatched rather than as one consistent typeface. Bundling
// removes the race entirely: every string uses the right font from the very
// first frame.
//
// Both are variable fonts (a single file spanning the whole weight axis),
// declared once per weight actually used in this app so FontWeight.w600
// etc. below resolves to that weight rather than being synthetically bolded.
// ---------------------------------------------------------------------------
class AppFonts {
  static const String heading = 'Outfit';
  static const String body = 'Inter';
}

class AppColors {
  // Primary palette — earthy greens
  static const Color primary = Color(0xFF2D6A4F);
  static const Color primaryLight = Color(0xFF40916C);
  static const Color primaryDark = Color(0xFF1B4332);

  // Accent — warm gold
  static const Color accent = Color(0xFFE9C46A);
  static const Color accentDark = Color(0xFFD4A03C);

  // Semantic
  static const Color success = Color(0xFF52B788);
  static const Color warning = Color(0xFFF4A261);
  static const Color error = Color(0xFFE76F51);
  static const Color info = Color(0xFF457B9D);

  // Neutrals
  static const Color background = Color(0xFFF8F9FA);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF1F3F5);
  static const Color textPrimary = Color(0xFF1A1A2E);
  static const Color textSecondary = Color(0xFF6C757D);
  static const Color textTertiary = Color(0xFFADB5BD);
  static const Color border = Color(0xFFDEE2E6);
  static const Color divider = Color(0xFFE9ECEF);

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF2D6A4F), Color(0xFF40916C)],
  );

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF1B4332), Color(0xFF2D6A4F), Color(0xFF40916C)],
  );

  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE9C46A), Color(0xFFF4A261)],
  );

  // Impact colours
  static const Color carbonColor = Color(0xFF457B9D);
  static const Color waterColor = Color(0xFF48CAE4);
  static const Color costColor = Color(0xFFE9C46A);
  static const Color nutritionColor = Color(0xFF52B788);
  static const Color landColor = Color(0xFFA68A64);
}

class AppTheme {
  static bool get isIOS {
    try {
      return Platform.isIOS;
    } catch (_) {
      return false;
    }
  }

  static TextTheme get _textTheme {
    return TextTheme(
      displayLarge: const TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 32,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      displayMedium: const TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 28,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
        letterSpacing: -0.5,
      ),
      headlineLarge: const TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      headlineMedium: const TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleLarge: const TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      titleMedium: const TextStyle(
        fontFamily: AppFonts.heading,
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: AppColors.textPrimary,
      ),
      bodyLarge: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: AppColors.textPrimary,
      ),
      bodyMedium: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: AppColors.textSecondary,
      ),
      bodySmall: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        fontWeight: FontWeight.w400,
        color: AppColors.textTertiary,
      ),
      labelLarge: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textPrimary,
      ),
      labelMedium: const TextStyle(
        fontFamily: AppFonts.body,
        fontSize: 12,
        fontWeight: FontWeight.w500,
        color: AppColors.textSecondary,
      ),
    );
  }

  static ThemeData get materialTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: AppColors.primary,
        primary: AppColors.primary,
        secondary: AppColors.accent,
        surface: AppColors.surface,
        error: AppColors.error,
      ),
      scaffoldBackgroundColor: AppColors.background,
      // Safety net: any Text() with no ambient DefaultTextStyle at all
      // still lands on Inter, never the platform default.
      fontFamily: AppFonts.body,
      textTheme: _textTheme,
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.surface,
        foregroundColor: AppColors.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 1,
        titleTextStyle: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 18,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.primary,
          side: const BorderSide(color: AppColors.primary, width: 1.5),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontFamily: AppFonts.body,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border, width: 0.5),
        ),
        color: AppColors.surface,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: AppColors.surfaceVariant,
        selectedColor: AppColors.primary.withValues(alpha: 0.15),
        labelStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 13,
          fontWeight: FontWeight.w500,
        ),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
        ),
        side: BorderSide.none,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceVariant,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.5),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        hintStyle: const TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 14,
          color: AppColors.textTertiary,
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: AppColors.surface,
        selectedItemColor: AppColors.primary,
        unselectedItemColor: AppColors.textTertiary,
        type: BottomNavigationBarType.fixed,
        elevation: 8,
      ),
    );
  }

  static CupertinoThemeData get cupertinoTheme {
    return CupertinoThemeData(
      primaryColor: AppColors.primary,
      barBackgroundColor: AppColors.surface.withValues(alpha: 0.94),
      scaffoldBackgroundColor: AppColors.background,
      textTheme: const CupertinoTextThemeData(
        primaryColor: AppColors.primary,
        navTitleTextStyle: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 17,
          fontWeight: FontWeight.w600,
          color: AppColors.textPrimary,
        ),
        navLargeTitleTextStyle: TextStyle(
          fontFamily: AppFonts.heading,
          fontSize: 34,
          fontWeight: FontWeight.w700,
          color: AppColors.textPrimary,
          letterSpacing: -0.5,
        ),
        textStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 16,
          color: AppColors.textPrimary,
        ),
        tabLabelTextStyle: TextStyle(
          fontFamily: AppFonts.body,
          fontSize: 10,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }
}

// Spacing constants
class Spacing {
  static const double xs = 4;
  static const double sm = 8;
  static const double md = 16;
  static const double lg = 24;
  static const double xl = 32;
  static const double xxl = 48;
}
