import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeProvider extends ChangeNotifier {
  static const _storageKey = 'theme_mode';

  ThemeMode _themeMode = ThemeMode.dark;
  bool _loaded = false;

  ThemeProvider() {
    _loadTheme();
  }

  ThemeMode get themeMode => _themeMode;
  bool get isDark => _themeMode == ThemeMode.dark;
  bool get isLoaded => _loaded;

  Future<void> toggleTheme() async {
    _themeMode =
        _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    notifyListeners();
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, _themeMode.name);
  }

  Future<void> _loadTheme() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored != null) {
      _themeMode = stored == ThemeMode.light.name
          ? ThemeMode.light
          : ThemeMode.dark;
    }
    _loaded = true;
    notifyListeners();
  }
}
