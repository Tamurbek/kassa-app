import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Common Colors
  static const Color primaryColor = Color(0xFF4F46E5);
  static const Color lightScaffoldBackground = Color(0xFFF8F9FA);
  static const Color darkScaffoldBackground = Color(0xFF1A1A1A);
  static const Color lightDividerColor = Color(0xFFE9ECEF);
  static const Color darkDividerColor = Color(0x14FFFFFF); // white.withOpacity(0.08)

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    scaffoldBackgroundColor: lightScaffoldBackground,
    cardColor: Colors.white,
    dividerColor: lightDividerColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF2D2D2D),
      primary: primaryColor,
      onPrimary: Colors.white,
      surface: lightScaffoldBackground,
      onSurface: const Color(0xFF212529),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.light().textTheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: const BorderSide(color: Color(0xFFE9ECEF)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Colors.white,
      foregroundColor: Color(0xFF2D2D2D),
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Color(0xFF2D2D2D)),
      titleTextStyle: TextStyle(
        color: Color(0xFF2D2D2D),
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: darkScaffoldBackground,
    cardColor: const Color(0xFF262626),
    dividerColor: darkDividerColor,
    colorScheme: ColorScheme.fromSeed(
      seedColor: const Color(0xFF818CF8),
      brightness: Brightness.dark,
      primary: const Color(0xFF818CF8),
      onPrimary: Colors.white,
      surface: darkScaffoldBackground,
      onSurface: const Color(0xFFE9ECEF),
    ),
    textTheme: GoogleFonts.interTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      elevation: 0,
      color: const Color(0xFF262626),
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(4),
        side: BorderSide(color: Colors.white.withOpacity(0.1)),
      ),
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: Color(0xFF121212),
      foregroundColor: Colors.white,
      elevation: 0,
      scrolledUnderElevation: 0,
      iconTheme: IconThemeData(color: Colors.white),
      titleTextStyle: TextStyle(
        color: Colors.white,
        fontSize: 18,
        fontWeight: FontWeight.bold,
      ),
    ),
  );
}
