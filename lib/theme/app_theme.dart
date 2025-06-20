import 'package:flutter/material.dart';

// Alipay Inspired Color Palette
const Color alipayBlue = Color(0xFF1677FF); // Primary Alipay Blue
const Color alipayLightBlue = Color(0xFFF0F8FF); // Lighter shade for backgrounds or accents
const Color alipayDarkSurface = Color(0xFF1D1D1D); // Dark mode surface
const Color alipayDarkBackground = Color(0xFF121212); // Dark mode background
const Color alipayLightSurface = Colors.white;
const Color alipayLightBackground = Color(0xFFF5F5F5);
const Color alipayTextLight = Color(0xFF333333);
const Color alipayTextDark = Color(0xFFE0E0E0);
const Color alipaySubtleTextLight = Color(0xFF757575);
const Color alipaySubtleTextDark = Color(0xFFB0B0B0);
const Color alipayError = Color(0xFFD32F2F);

class AppTheme {
  static ThemeData get lightTheme {
    return ThemeData(
      brightness: Brightness.light,
      primaryColor: alipayBlue,
      scaffoldBackgroundColor: alipayLightBackground,
      colorScheme: const ColorScheme.light(
        primary: alipayBlue,
        secondary: alipayBlue, // Accent color, can be same as primary or different
        surface: alipayLightSurface,
        background: alipayLightBackground,
        error: alipayError,
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: alipayTextLight,
        onBackground: alipayTextLight,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        color: alipayBlue, // AppBar background
        elevation: 0.5,
        centerTitle: false, // Update centerTitle to false
        iconTheme: IconThemeData(color: Colors.white), // AppBar icons
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w600,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: alipayTextLight),
        bodyMedium: TextStyle(color: alipayTextLight),
        titleLarge: TextStyle(color: alipayTextLight, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: alipayTextLight),
        labelLarge: TextStyle(color: alipayBlue, fontWeight: FontWeight.bold), // For buttons
      ),
      iconTheme: const IconThemeData(
        color: alipayBlue, // Default icon color
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: alipayBlue,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: alipayBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: alipayBlue,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: alipayBlue,
          side: const BorderSide(color: alipayBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: alipaySubtleTextLight),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: alipayBlue, width: 2.0),
        ),
        labelStyle: const TextStyle(color: alipaySubtleTextLight),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: alipayLightSurface,
        selectedItemColor: alipayBlue,
        unselectedItemColor: alipaySubtleTextLight,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, color: alipayBlue),
        unselectedLabelStyle: const TextStyle(color: alipaySubtleTextLight),
        type: BottomNavigationBarType.fixed,
      ),
      // Add other theme properties as needed
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      brightness: Brightness.dark,
      primaryColor: alipayBlue,
      scaffoldBackgroundColor: alipayDarkBackground,
      colorScheme: const ColorScheme.dark(
        primary: alipayBlue,
        secondary: alipayBlue,
        surface: alipayDarkSurface,
        background: alipayDarkBackground,
        error: alipayError,
        onPrimary: Colors.white, // Text on primary color buttons
        onSecondary: Colors.white,
        onSurface: alipayTextDark,
        onBackground: alipayTextDark,
        onError: Colors.white,
      ),
      appBarTheme: const AppBarTheme(
        color: alipayDarkSurface, // Darker AppBar for dark mode
        elevation: 0.5,
        centerTitle: false, // Update centerTitle to false
        iconTheme: IconThemeData(color: Colors.white),
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.w500,
        ),
      ),
      textTheme: const TextTheme(
        bodyLarge: TextStyle(color: alipayTextDark),
        bodyMedium: TextStyle(color: alipayTextDark),
        titleLarge: TextStyle(color: alipayTextDark, fontWeight: FontWeight.bold),
        titleMedium: TextStyle(color: alipayTextDark),
        labelLarge: TextStyle(color: alipayBlue, fontWeight: FontWeight.bold),
      ),
      iconTheme: const IconThemeData(
        color: alipayBlue, // Default icon color for dark mode
      ),
      buttonTheme: ButtonThemeData(
        buttonColor: alipayBlue,
        textTheme: ButtonTextTheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: alipayBlue,
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: alipayBlue,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: alipayBlue,
          side: const BorderSide(color: alipayBlue),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8.0)),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: alipaySubtleTextDark),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(8.0),
          borderSide: const BorderSide(color: alipayBlue, width: 2.0),
        ),
        labelStyle: const TextStyle(color: alipaySubtleTextDark),
      ),
      bottomNavigationBarTheme: BottomNavigationBarThemeData(
        backgroundColor: alipayDarkSurface,
        selectedItemColor: alipayBlue,
        unselectedItemColor: alipaySubtleTextDark,
        selectedLabelStyle: const TextStyle(fontWeight: FontWeight.bold, color: alipayBlue),
        unselectedLabelStyle: const TextStyle(color: alipaySubtleTextDark),
        type: BottomNavigationBarType.fixed,
      ),
      // Add other theme properties as needed
    );
  }
}
