import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Ahl Design System & Color Palette
/// Tailored for GCC joint household finance:
/// Deep Teal, Muted Antique Gold, Warm Cream, Charcoal, Terracotta
class AppTheme {
  // Brand Colors
  static const Color primaryTeal = Color(0xFF0F6E56); // Deep Teal (Trust & Inflows)
  static const Color primaryTealDark = Color(0xFF0A4F3D);
  static const Color primaryTealLight = Color(0xFFE8F4F0);
  static const Color primaryTealBorder = Color(0xFFB4DDD1);

  // Muted Antique Gold (Reserved exclusively for Zakat & Attribution)
  static const Color accentGold = Color(0xFFC9962C);
  static const Color accentGoldLight = Color(0xFFFBF5E9);
  static const Color accentGoldBorder = Color(0xFFE9D39E);

  // Backgrounds & Surfaces
  static const Color creamBg = Color(0xFFFAF8F3); // Warm Cream
  static const Color surfaceCard = Color(0xFFFFFFFF); // Pure White Cards
  static const Color surfaceMuted = Color(0xFFF3EFE6);
  static const Color surfaceBorder = Color(0xFFE8E4D9);

  // Inks & Typography
  static const Color inkPrimary = Color(0xFF1C1B19); // Near-black Charcoal
  static const Color inkSecondary = Color(0xFF5E5B54);
  static const Color inkMuted = Color(0xFF8C887E);

  // Outflow & Warning
  static const Color terracotta = Color(0xFFB5453A); // Muted Terracotta (Outflows/Alerts)
  static const Color terracottaLight = Color(0xFFFDEEEC);
  static const Color terracottaBorder = Color(0xFFEBBBB5);

  // Typography Getters
  /// Editorial Serif for English headlines
  static TextStyle editorialHeading({
    double fontSize = 26,
    FontWeight fontWeight = FontWeight.w600,
    Color color = inkPrimary,
    String lang = 'ar',
  }) {
    if (lang == 'ar') {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: 1.3,
      );
    }
    return GoogleFonts.newsreader(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: -0.5,
      height: 1.25,
    );
  }

  /// App bar brand title
  static TextStyle brandTitle({String lang = 'ar', Color color = inkPrimary}) {
    if (lang == 'ar') {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: 20,
        fontWeight: FontWeight.w700,
        color: color,
      );
    }
    return GoogleFonts.newsreader(
      fontSize: 22,
      fontWeight: FontWeight.w700,
      color: color,
      letterSpacing: -0.4,
    );
  }

  /// Body text
  static TextStyle body({
    double fontSize = 14,
    FontWeight fontWeight = FontWeight.normal,
    Color color = inkSecondary,
    String lang = 'ar',
    double? height,
  }) {
    if (lang == 'ar') {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
        height: height ?? 1.5,
      );
    }
    return GoogleFonts.ibmPlexSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      height: height ?? 1.45,
    );
  }

  /// Medium weight body text
  static TextStyle bodyMedium({
    double fontSize = 14,
    Color color = inkPrimary,
    String lang = 'ar',
  }) {
    return body(
      fontSize: fontSize,
      fontWeight: FontWeight.w600,
      color: color,
      lang: lang,
    );
  }

  /// Tabular Monospace font for exact financial amounts & calculations
  static TextStyle amountMonospace({
    double fontSize = 18,
    FontWeight fontWeight = FontWeight.w700,
    Color color = inkPrimary,
    double letterSpacing = -0.3,
  }) {
    return GoogleFonts.ibmPlexMono(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: letterSpacing,
    );
  }

  /// Label & Tag text
  static TextStyle label({
    double fontSize = 12,
    FontWeight fontWeight = FontWeight.w600,
    Color color = inkMuted,
    String lang = 'ar',
  }) {
    if (lang == 'ar') {
      return GoogleFonts.ibmPlexSansArabic(
        fontSize: fontSize,
        fontWeight: fontWeight,
        color: color,
      );
    }
    return GoogleFonts.ibmPlexSans(
      fontSize: fontSize,
      fontWeight: fontWeight,
      color: color,
      letterSpacing: 0.2,
    );
  }

  static ThemeData get theme => ThemeData(
        useMaterial3: true,
        scaffoldBackgroundColor: creamBg,
        primaryColor: primaryTeal,
        colorScheme: const ColorScheme.light(
          primary: primaryTeal,
          secondary: accentGold,
          surface: surfaceCard,
          error: terracotta,
        ),
        appBarTheme: const AppBarTheme(
          backgroundColor: creamBg,
          elevation: 0,
          scrolledUnderElevation: 0,
          centerTitle: true,
          iconTheme: IconThemeData(color: inkPrimary),
        ),
        cardTheme: CardThemeData(
          color: surfaceCard,
          elevation: 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: surfaceBorder, width: 1),
          ),
          margin: EdgeInsets.zero,
        ),
        dividerColor: surfaceBorder,
        dialogTheme: DialogThemeData(
          backgroundColor: surfaceCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        ),
        bottomSheetTheme: const BottomSheetThemeData(
          backgroundColor: surfaceCard,
          elevation: 8,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
        ),
      );
}
