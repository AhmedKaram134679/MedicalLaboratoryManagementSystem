import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/database_service.dart';
import 'dart:convert';

class AppProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  Locale _locale = const Locale('ar');
  UserModel? _currentUser;
  bool _hasUnsavedChanges = false;

  ThemeMode get themeMode => _themeMode;
  Locale get locale => _locale;
  UserModel? get currentUser => _currentUser;
  bool get isAdmin => _currentUser?.role == 'admin';
  bool get hasUnsavedChanges => _hasUnsavedChanges;

  void setHasUnsavedChanges(bool value) {
    if (_hasUnsavedChanges != value) {
      _hasUnsavedChanges = value;
      notifyListeners();
    }
  }

  AppProvider() {
    _loadSettings();
  }

  void login(UserModel user) {
    _currentUser = user;
    _saveSettings();
    notifyListeners();
  }

  void logout() {
    _currentUser = null;
    _saveSettings();
    notifyListeners();
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light
        ? ThemeMode.dark
        : ThemeMode.light;
    _saveSettings();
    notifyListeners();
  }

  void setLocale(Locale newLocale) {
    _locale = newLocale;
    _saveSettings();
    notifyListeners();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final isDark = prefs.getBool('isDark') ?? false;
    final langCode = prefs.getString('lang') ?? 'ar';
    final userJson = prefs.getString('user');

    _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
    _locale = Locale(langCode);
    if (userJson != null) {
      try {
        final cachedUser = UserModel.fromMap(json.decode(userJson));
        if (cachedUser.id != null) {
          // Strictly verify user and fetch latest role directly from SQLite users table
          final db = await DatabaseService().database;
          final userRows = await db.query(
            'users',
            where: 'id = ?',
            whereArgs: [cachedUser.id],
          );
          if (userRows.isNotEmpty) {
            _currentUser = UserModel.fromMap(userRows.first);
          } else {
            // User deleted or invalid in database: clear session to prevent privilege escalation
            _currentUser = null;
            await prefs.remove('user');
          }
        } else {
          _currentUser = null;
          await prefs.remove('user');
        }
      } catch (_) {
        _currentUser = null;
        await prefs.remove('user');
      }
    }
    notifyListeners();
  }

  Future<void> _saveSettings() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isDark', _themeMode == ThemeMode.dark);
    await prefs.setString('lang', _locale.languageCode);
    if (_currentUser != null) {
      final userMap = _currentUser!.toMap();
      userMap['password'] = ''; // Never store plaintext password in preferences
      await prefs.setString('user', json.encode(userMap));
    } else {
      await prefs.remove('user');
    }
  }
}
