import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'constants.dart';

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    primaryColor: AppConstants.primaryColor,
    scaffoldBackgroundColor: const Color(0xFF0F172A),
    colorScheme: const ColorScheme.dark(
      primary: AppConstants.primaryColor,
      secondary: Colors.cyan,
      surface: Color(0xFF1E293B),
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.dark().textTheme),
    cardTheme: CardThemeData(
      color: Color(0xFF1E293B),
      shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16)
      ),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    primaryColor: AppConstants.primaryColor,
    scaffoldBackgroundColor: const Color(0xFFF8FAFC),
    colorScheme: const ColorScheme.light(
      primary: AppConstants.primaryColor,
      secondary: Colors.cyan,
      surface: Colors.white,
    ),
    textTheme: GoogleFonts.poppinsTextTheme(ThemeData.light().textTheme),
    cardTheme: CardThemeData(
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
    ),
  );
}
