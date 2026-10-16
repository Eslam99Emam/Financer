import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ThemeController extends ChangeNotifier {
  static const _key = 'finance_theme_mode_v1';
  final SharedPreferences _prefs;
  ThemeMode _mode;
  ThemeMode get mode => _mode;

  ThemeController._(this._prefs, this._mode);

  static Future<ThemeController> init() async {
    final prefs = await SharedPreferences.getInstance();
    final saved = prefs.getString(_key);
    final mode = switch (saved) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    return ThemeController._(prefs, mode);
  }

  Future<void> setMode(ThemeMode mode) async {
    _mode = mode;
    await _prefs.setString(
        _key,
        switch (mode) {
          ThemeMode.light => 'light',
          ThemeMode.dark => 'dark',
          ThemeMode.system => 'system',
        });
    notifyListeners();
  }

  /// Reset in-memory and persisted preference to system-default mode.
  Future<void> reset({bool persist = false}) async {
    _mode = ThemeMode.system;
    if (persist) await _prefs.remove(_key);
    notifyListeners();
  }
}
