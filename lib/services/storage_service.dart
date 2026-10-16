import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

/// Persists the entire finance state as one versioned JSON snapshot.
class StorageService {
  static const _key = 'budget_state_v2';
  static const _legacyKey = 'budget_state_v1';
  final SharedPreferences _prefs;

  StorageService._(this._prefs);
  static Future<StorageService> init() async =>
      StorageService._(await SharedPreferences.getInstance());

  Map<String, dynamic>? read() {
    // If the current snapshot is malformed, still attempt the original v1 key.
    for (final key in [_key, _legacyKey]) {
      final raw = _prefs.getString(key);
      if (raw == null) continue;
      try {
        final value = jsonDecode(raw);
        if (value is Map<String, dynamic>) return value;
      } catch (_) {
        // Try the legacy snapshot next.
      }
    }
    return null;
  }

  Future<void> write(Map<String, dynamic> value) async {
    await _prefs.setString(_key, jsonEncode(value));
    await _prefs.remove(_legacyKey);
  }

  Future<void> clearAll() async {
    await _prefs.clear();
  }
}
