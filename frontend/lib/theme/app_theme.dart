import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Jupiter Arena – Light, clean SaaS theme.
/// Backgrounds: Pure White, light grey cards.
/// Primary: Soft Indigo / Periwinkle.
class AppTheme {
  AppTheme._();

  static const Color primary = Color(0xFF8A8EF2);
  static const Color primaryDark = Color(0xFF6B6FCF);
  static const Color surface = Color(0xFFFFFFFF);
  static const Color surfaceVariant = Color(0xFFF8F9FA);
  static const Color onSurface = Color(0xFF1A1A1A);
  static const Color onPrimary = Color(0xFFFFFFFF);
  static const Color outline = Color(0xFFE0E0E0);
  static const Color success = Color(0xFF22C55E);
  static const Color error = Color(0xFFE53935);

  static ThemeData get light {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      scaffoldBackgroundColor: surface,
      colorScheme: const ColorScheme.light(
        primary: primary,
        onPrimary: onPrimary,
        surface: surface,
        onSurface: onSurface,
        secondary: primaryDark,
        onSecondary: onPrimary,
        error: error,
        outline: outline,
      ),
      textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme).copyWith(
        bodyLarge: GoogleFonts.poppins(color: onSurface),
        bodyMedium: GoogleFonts.poppins(color: onSurface),
        titleLarge: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: onSurface),
        titleMedium: GoogleFonts.poppins(fontWeight: FontWeight.w600, color: onSurface),
        labelLarge: GoogleFonts.poppins(fontWeight: FontWeight.w500),
      ),
      appBarTheme: AppBarTheme(
        backgroundColor: surface,
        foregroundColor: onSurface,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(fontSize: 18, fontWeight: FontWeight.w600, color: onSurface),
      ),
      cardTheme: CardThemeData(
        color: surfaceVariant,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        margin: const EdgeInsets.all(0),
        clipBehavior: Clip.antiAlias,
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: primary,
          foregroundColor: onPrimary,
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          textStyle: GoogleFonts.poppins(fontWeight: FontWeight.w600),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surfaceVariant,
        labelStyle: GoogleFonts.poppins(color: onSurface),
        hintStyle: GoogleFonts.poppins(color: Colors.grey),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primary, width: 2),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: outline),
        ),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: onSurface,
        contentTextStyle: GoogleFonts.poppins(color: surface),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}
