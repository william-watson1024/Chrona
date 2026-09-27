import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

class FocusSettingsProvider extends ChangeNotifier {
  FocusSettingsProvider() : _breakDurationSeconds = defaultBreakDurationSeconds;

  FocusSettingsProvider.inMemory({
    int breakDurationSeconds = defaultBreakDurationSeconds,
  })  : _breakDurationSeconds = breakDurationSeconds,
        _isLoaded = true,
        _isInMemory = true;

  static const defaultBreakDurationSeconds = 5 * 60;

  static const _breakDurationKey = 'break_duration_seconds';

  int _breakDurationSeconds;
  bool _isLoaded = false;
  bool _isInMemory = false;

  int get breakDurationSeconds => _breakDurationSeconds;
  bool get isLoading => !_isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;

    final preferences = await SharedPreferences.getInstance();
    _breakDurationSeconds =
        preferences.getInt(_breakDurationKey) ?? defaultBreakDurationSeconds;
    _isLoaded = true;
    notifyListeners();
  }

  Future<void> updateBreakDuration(int breakDurationSeconds) async {
    if (breakDurationSeconds <= 0) return;

    _breakDurationSeconds = breakDurationSeconds;
    _isLoaded = true;
    notifyListeners();

    if (_isInMemory) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(_breakDurationKey, breakDurationSeconds);
  }
}
