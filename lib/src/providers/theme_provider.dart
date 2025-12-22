import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends AsyncNotifier<ThemeMode> {
  static const _storageKey = 'theme_mode';

  @override
  Future<ThemeMode> build() async {
    final prefs = await SharedPreferences.getInstance();
    final stored = prefs.getString(_storageKey);
    if (stored == ThemeMode.light.name) return ThemeMode.light;
    if (stored == ThemeMode.dark.name) return ThemeMode.dark;
    return ThemeMode.dark;
  }

  Future<void> toggleTheme() async {
    final current = state.value ?? ThemeMode.dark;
    final next = current == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    state = AsyncData(next);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_storageKey, next.name);
  }
}

final themeControllerProvider =
    AsyncNotifierProvider<ThemeController, ThemeMode>(
        ThemeController.new);
