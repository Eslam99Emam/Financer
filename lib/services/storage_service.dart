import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

/// Stores the whole app state as one JSON string.
class StorageService {
  static const _key = 'budget_state_v1';
  final SharedPreferences _prefs;

  StorageService._(this._prefs);

  static Future<StorageService> init() async =>
      StorageService._(await SharedPreferences.getInstance());

  /// Returns the saved snapshot, or null if none / unreadable.
  Map<String, dynamic>? read() {
    final raw = _prefs.getString(_key);
    if (raw == null) return null;
    try {
      final data = jsonDecode(raw);
      return data is Map<String, dynamic> ? data : null;
    } catch (_) {
      return null;
    }
  }

  Future<void> write(Map<String, dynamic> data) =>
      _prefs.setString(_key, jsonEncode(data));
}
