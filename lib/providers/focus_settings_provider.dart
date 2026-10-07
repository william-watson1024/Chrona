import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum ReminderMode { ring, vibrate, ringAndVibrate, notificationOnly }

class FocusSettingsProvider extends ChangeNotifier {
  FocusSettingsProvider()
      : _breakDurationSeconds = defaultBreakDurationSeconds,
        _reminderMode = defaultReminderMode;

  FocusSettingsProvider.inMemory({
    int breakDurationSeconds = defaultBreakDurationSeconds,
    ReminderMode reminderMode = defaultReminderMode,
  })  : _breakDurationSeconds = breakDurationSeconds,
        _reminderMode = reminderMode,
        _isLoaded = true,
        _isInMemory = true;

  static const defaultBreakDurationSeconds = 5 * 60;
  static const defaultReminderMode = ReminderMode.ringAndVibrate;

  static const _breakDurationKey = 'break_duration_seconds';
  static const reminderModeKey = 'reminder_mode';

  int _breakDurationSeconds;
  ReminderMode _reminderMode;
  bool _isLoaded = false;
  bool _isInMemory = false;

  int get breakDurationSeconds => _breakDurationSeconds;
  ReminderMode get reminderMode => _reminderMode;
  bool get isLoading => !_isLoaded;

  Future<void> load() async {
    if (_isLoaded) return;

    final preferences = await SharedPreferences.getInstance();
    _breakDurationSeconds =
        preferences.getInt(_breakDurationKey) ?? defaultBreakDurationSeconds;
    _reminderMode = ReminderMode.values.firstWhere(
      (mode) => mode.name == preferences.getString(reminderModeKey),
      orElse: () => defaultReminderMode,
    );
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

  Future<void> updateReminderMode(ReminderMode reminderMode) async {
    _reminderMode = reminderMode;
    _isLoaded = true;
    notifyListeners();

    if (_isInMemory) return;

    final preferences = await SharedPreferences.getInstance();
    await preferences.setString(reminderModeKey, reminderMode.name);
  }
}
