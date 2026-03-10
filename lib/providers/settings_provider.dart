import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SettingsProvider with ChangeNotifier {
  bool _isGridView = true;
  SharedPreferences? _prefs;

  bool get isGridView => _isGridView;

  SettingsProvider() {
    _loadSettings();
  }

  Future<void> _loadSettings() async {
    _prefs = await SharedPreferences.getInstance();
    _isGridView = _prefs?.getBool('isGridView') ?? true;
    notifyListeners();
  }

  Future<void> toggleViewMode() async {
    _isGridView = !_isGridView;
    await _prefs?.setBool('isGridView', _isGridView);
    notifyListeners();
  }
}
