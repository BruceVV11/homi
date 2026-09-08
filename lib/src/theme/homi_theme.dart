import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

abstract final class HomiColors {
  static const coral = Color(0xFFFF6B5E);
  static const peach = Color(0xFFFFB08A);
  static const sage = Color(0xFFA7B89F);
  static const cream = Color(0xFFFFF8F2);
  static const slate = Color(0xFF2E2E2E);
  static const muted = Color(0xFF77736F);
  static const border = Color(0xFFEDE5DF);
  static const surface = Colors.white;
}

abstract final class HomiTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: HomiColors.coral,
      onPrimary: Colors.white,
      secondary: HomiColors.sage,
      onSecondary: HomiColors.slate,
      surface: HomiColors.surface,
      onSurface: HomiColors.slate,
      error: Color(0xFFB3261E),
    );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: HomiColors.cream,
    );
    final textTheme = GoogleFonts.nunitoTextTheme(base.textTheme).copyWith(
      displaySmall: GoogleFonts.nunito(
        fontSize: 34,
        fontWeight: FontWeight.w800,
        height: 1.05,
        color: HomiColors.slate,
      ),
      headlineSmall: GoogleFonts.nunito(
        fontSize: 24,
        fontWeight: FontWeight.w800,
        height: 1.15,
        color: HomiColors.slate,
      ),
      titleLarge: GoogleFonts.nunito(
        fontSize: 18,
        fontWeight: FontWeight.w800,
        color: HomiColors.slate,
      ),
      bodyLarge: GoogleFonts.nunito(
        fontSize: 16,
        height: 1.4,
        color: HomiColors.slate,
      ),
      bodyMedium: GoogleFonts.nunito(
        fontSize: 14,
        height: 1.4,
        color: HomiColors.muted,
      ),
    );

    return base.copyWith(
      textTheme: textTheme,
      cardTheme: CardThemeData(
        color: HomiColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
          side: const BorderSide(color: HomiColors.border),
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: HomiColors.coral,
          foregroundColor: Colors.white,
          minimumSize: const Size(0, 54),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: HomiColors.slate,
          minimumSize: const Size(0, 54),
          side: const BorderSide(color: HomiColors.border),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          textStyle: GoogleFonts.nunito(fontSize: 15, fontWeight: FontWeight.w800),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: HomiColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: HomiColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: HomiColors.coral, width: 1.6),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: const BorderSide(color: Color(0xFFB3261E)),
        ),
      ),
    );
  }
}
