import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Paytm palette
  static const Color navyBlue    = Color(0xFF002970);
  static const Color paytmBlue   = Color(0xFF00B9F1);
  static const Color lightBlue   = Color(0xFFE8F4FD);
  static const Color yellow      = Color(0xFFFFD700);
  static const Color green       = Color(0xFF4CAF50);
  static const Color orange      = Color(0xFFFF9800);
  static const Color red         = Color(0xFFE53935);

  // Legacy aliases so existing code keeps compiling unchanged
  static const Color primaryColor   = navyBlue;
  static const Color secondaryColor = paytmBlue;
  static const Color accentColor    = Color(0xFF7C4DFF);
  static const Color successColor   = green;
  static const Color warningColor   = orange;
  static const Color errorColor     = red;
  static const Color offlineColor   = Color(0xFFFF7043);
  static const Color surfaceColor   = lightBlue;
  static const Color cardColor      = Colors.white;

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      colorScheme: ColorScheme.fromSeed(
        seedColor: navyBlue,
        primary: navyBlue,
        secondary: paytmBlue,
        surface: lightBlue,
      ),
      scaffoldBackgroundColor: lightBlue,
      textTheme: GoogleFonts.poppinsTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: lightBlue,
        foregroundColor: navyBlue,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        centerTitle: true,
        titleTextStyle: GoogleFonts.poppins(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          color: navyBlue,
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: navyBlue,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: GoogleFonts.poppins(
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
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
          borderSide: const BorderSide(color: navyBlue, width: 2),
        ),
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
      ),
      cardTheme: CardThemeData(
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
        color: cardColor,
      ),
    );
  }
}
