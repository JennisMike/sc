import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A provider that exposes the current theme mode
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((ref) {
  return ThemeModeNotifier();
});

/// Notifier class for managing theme mode state
class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadThemePreference();
  }

  /// Load theme preference from shared preferences
  Future<void> _loadThemePreference() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final isDarkMode = prefs.getBool('darkMode') ?? false;
      state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      // Fall back to system theme if there's an error
      state = ThemeMode.system;
    }
  }

  /// Toggle between light and dark mode
  Future<void> toggleTheme(bool isDarkMode) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setBool('darkMode', isDarkMode);
      state = isDarkMode ? ThemeMode.dark : ThemeMode.light;
    } catch (e) {
      // If there's an error, don't change the state
    }
  }
}
