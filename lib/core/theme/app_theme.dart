import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Brand theme for Lanka Bus passenger app.
class AppTheme {
  AppTheme._();

  static const Color _primary = Color(0xFF0B6E4F);
  static const Color _secondary = Color(0xFFE8B931);
  static const Color _surface = Color(0xFFF7F4EF);
  static const Color _error = Color(0xFFB3261E);

  static ThemeData get light {
    final base = ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: _primary,
        primary: _primary,
        secondary: _secondary,
        surface: _surface,
        error: _error,
        brightness: Brightness.light,
      ),
    );

    return base.copyWith(
      textTheme: GoogleFonts.dmSansTextTheme(base.textTheme),
      appBarTheme: AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: _primary,
        foregroundColor: Colors.white,
        titleTextStyle: GoogleFonts.dmSans(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: Colors.white,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: _primary,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
    );
  }
}
