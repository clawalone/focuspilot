import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsService extends ChangeNotifier {
  static const String _keyThemeMode = 'theme_mode';
  static const String _keyFocusDuration = 'focus_duration';
  static const String _keyDailyGoal = 'daily_goal';
  static const String _keyAutoBreak = 'auto_break';

  static const String _keyDndEnabled = 'dnd_enabled';
  static const String _keyNotificationsEnabled = 'notifications_enabled';

  final SharedPreferences _prefs;

  SettingsService(this._prefs);

  static Future<SettingsService> init() async {
    final prefs = await SharedPreferences.getInstance();
    return SettingsService(prefs);
  }

  // Theme Mode
  ThemeMode getThemeMode() {
    final int? index = _prefs.getInt(_keyThemeMode);
    if (index == null) return ThemeMode.system;
    return ThemeMode.values[index];
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    await _prefs.setInt(_keyThemeMode, mode.index);
    notifyListeners();
  }

  // Focus Duration (in minutes)
  int getFocusDuration() {
    return _prefs.getInt(_keyFocusDuration) ?? 25;
  }

  Future<void> setFocusDuration(int minutes) async {
    await _prefs.setInt(_keyFocusDuration, minutes);
    notifyListeners();
  }

  // Daily Goal (in minutes)
  int getDailyGoal() {
    return _prefs.getInt(_keyDailyGoal) ?? 120; // Default 2 hours
  }

  Future<void> setDailyGoal(int minutes) async {
    await _prefs.setInt(_keyDailyGoal, minutes);
    notifyListeners();
  }

  // Auto Break
  bool getAutoBreak() {
    return _prefs.getBool(_keyAutoBreak) ?? false;
  }

  Future<void> setAutoBreak(bool enabled) async {
    await _prefs.setBool(_keyAutoBreak, enabled);
    notifyListeners();
  }

  // DND Enabled
  bool getDndEnabled() {
    return _prefs.getBool(_keyDndEnabled) ?? true;
  }

  Future<void> setDndEnabled(bool enabled) async {
    await _prefs.setBool(_keyDndEnabled, enabled);
    notifyListeners();
  }

  // Notifications
  bool getNotificationsEnabled() {
    return _prefs.getBool(_keyNotificationsEnabled) ?? true;
  }

  Future<void> setNotificationsEnabled(bool enabled) async {
    await _prefs.setBool(_keyNotificationsEnabled, enabled);
    notifyListeners();
  }
}
