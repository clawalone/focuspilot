import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // Vibrant Palette
  static const Color background = Color(
    0xFFF8F9FE,
  ); // Slight off-white for depth
  static const Color primaryText = Color(0xFF1A1B2E);
  static const Color secondaryText = Color(0xFF8F9BB3);

  static const Color primaryColor = Color(0xFF6C63FF); // Vibrant Purple
  static const Color secondaryColor = Color(0xFF00D2D3); // Bright Teal
  static const Color accentPink = Color(0xFFFF6B6B); // Pop Pink
  static const Color accentYellow = Color(0xFFFECA57); // Warm Yellow

  // Card Colors (More saturated but light)
  static const Color cardWork = Color(0xFFE3F2FD); // Light Blue
  static const Color cardPersonal = Color(0xFFF3E5F5); // Light Purple
  static const Color cardReading = Color(0xFFFFF3E0); // Light Orange
  static const Color cardSleep = Color(0xFFE0F2F1); // Light Teal

  // Dark Mode Card Colors
  static const Color cardWorkDark = Color(0xFF1A237E); // Deep Blue
  static const Color cardPersonalDark = Color(0xFF4A148C); // Deep Purple
  static const Color cardReadingDark = Color(0xFFE65100); // Deep Orange
  static const Color cardSleepDark = Color(0xFF004D40); // Deep Teal

  // Gradients
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient fabGradient = LinearGradient(
    colors: [Color(0xFFFF9F43), Color(0xFFFF6B6B)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  // Stats Dark Theme (Keeping as is for now, maybe tweak)
  static const Color statsDarkBackground = Color(0xFF0F0F1E);
  static const Color statsCardBackground = Color(0xFF1A1A2E);
  static const Color statsAccentGreen = Color(0xFF00E676); // Brighter Green
  static const Color statsAccentPurple = Color(0xFF7C4DFF);
  static const Color statsTextWhite = Color(0xFFFFFFFF);
  static const Color statsTextGrey = Color(0xFF8F9BB3);

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: background,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: Colors.white,
        background: background,
        onSurface: primaryText,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: primaryText),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: primaryColor.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: primaryText,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: primaryText,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: primaryText,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: secondaryText,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: primaryText,
        ),
      ),
      iconTheme: const IconThemeData(color: primaryText, size: 24),
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      scaffoldBackgroundColor: statsDarkBackground,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: secondaryColor,
        surface: statsCardBackground,
        background: statsDarkBackground,
        onSurface: statsTextWhite,
        brightness: Brightness.dark,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        iconTheme: IconThemeData(color: statsTextWhite),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: primaryColor,
          foregroundColor: Colors.white,
          elevation: 8,
          shadowColor: Colors.black.withOpacity(0.4),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      textTheme: TextTheme(
        displayLarge: GoogleFonts.outfit(
          fontSize: 36,
          fontWeight: FontWeight.bold,
          color: statsTextWhite,
          letterSpacing: -1.0,
        ),
        displayMedium: GoogleFonts.outfit(
          fontSize: 28,
          fontWeight: FontWeight.w600,
          color: statsTextWhite,
          letterSpacing: -0.5,
        ),
        titleLarge: GoogleFonts.outfit(
          fontSize: 20,
          fontWeight: FontWeight.w600,
          color: statsTextWhite,
        ),
        bodyLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.normal,
          color: statsTextWhite,
        ),
        bodyMedium: GoogleFonts.outfit(
          fontSize: 14,
          fontWeight: FontWeight.normal,
          color: statsTextGrey,
        ),
        labelLarge: GoogleFonts.outfit(
          fontSize: 16,
          fontWeight: FontWeight.w600,
          color: statsTextWhite,
        ),
      ),
      iconTheme: const IconThemeData(color: statsTextWhite, size: 24),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: Colors.transparent,
        indicatorColor: primaryColor.withOpacity(0.2),
        labelTextStyle: MaterialStateProperty.all(
          GoogleFonts.outfit(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: statsTextWhite,
          ),
        ),
        iconTheme: MaterialStateProperty.resolveWith((states) {
          if (states.contains(MaterialState.selected)) {
            return const IconThemeData(color: statsTextWhite);
          }
          return const IconThemeData(color: statsTextGrey);
        }),
      ),
    );
  }
}
