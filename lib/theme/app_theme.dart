import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Bespoke Color Palette: Warm Paper, Deep Pine, Warm Amber & Crisp Ink
  static const Color paperBg = Color(0xFFFBFBF9);
  static const Color surfaceCard = Color(0xFFFFFFFF);
  static const Color surfaceMuted = Color(0xFFF3F2EE);
  static const Color surfaceBorder = Color(0xFFE8E6DF);

  // Ink Colors
  static const Color inkPrimary = Color(0xFF191817);
  static const Color inkSecondary = Color(0xFF595752);
  static const Color inkMuted = Color(0xFF8C8980);

  // Brand Accents
  static const Color pinePrimary = Color(0xFF0F5132); // Deep Forest Pine
  static const Color pineDark = Color(0xFF093622);
  static const Color pineLight = Color(0xFFE9F4EE);
  static const Color pineBorder = Color(0xFFB5DEC9);

  // Warm Highlights
  static const Color ochreAccent = Color(0xFFC27803);
  static const Color ochreLight = Color(0xFFFEF7EA);
  static const Color terracotta = Color(0xFFC2410C);
  static const Color terracottaLight = Color(0xFFFEE2E2);

  // Typography
  static TextStyle get brandTitle => GoogleFonts.fraunces(
        fontSize: 22,
        fontWeight: FontWeight.w700,
        color: inkPrimary,
        letterSpacing: -0.5,
      );

  static TextStyle get editorialHeading => GoogleFonts.fraunces(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: inkPrimary,
        letterSpacing: -0.6,
      );

  static TextStyle get sectionHeading => GoogleFonts.plusJakartaSans(
        fontSize: 11,
        fontWeight: FontWeight.w800,
        color: inkMuted,
        letterSpacing: 1.1,
      );

  static TextStyle get body => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        color: inkSecondary,
        height: 1.45,
      );

  static TextStyle get bodyMedium => GoogleFonts.plusJakartaSans(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: inkPrimary,
      );

  static TextStyle get amountMonospace => GoogleFonts.spaceGrotesk(
        fontSize: 16,
        fontWeight: FontWeight.w700,
        color: inkPrimary,
        letterSpacing: -0.3,
      );

  static TextStyle get tagText => GoogleFonts.spaceGrotesk(
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.2,
      );

  static ThemeData get theme => ThemeData(
        scaffoldBackgroundColor: paperBg,
        primaryColor: pinePrimary,
        colorScheme: const ColorScheme.light(
          primary: pinePrimary,
          secondary: ochreAccent,
          surface: surfaceCard,
        ),
        appBarTheme: AppBarTheme(
          backgroundColor: paperBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: const IconThemeData(color: inkPrimary),
          titleTextStyle: brandTitle,
        ),
        dividerColor: surfaceBorder,
      );
}
