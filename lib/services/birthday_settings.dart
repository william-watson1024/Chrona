import 'package:shared_preferences/shared_preferences.dart';

class BirthdaySettings {
  static const birthdayMonthKey = 'birthday_month';
  static const birthdayDayKey = 'birthday_day';

  const BirthdaySettings._();

  static Future<DateTime?> load() async {
    final preferences = await SharedPreferences.getInstance();
    final month = preferences.getInt(birthdayMonthKey);
    final day = preferences.getInt(birthdayDayKey);
    if (!_isValidMonthDay(month, day)) return null;
    return DateTime(2000, month!, day!);
  }

  static Future<void> save({required int month, required int day}) async {
    if (!_isValidMonthDay(month, day)) {
      throw ArgumentError('Invalid birthday month/day');
    }
    final preferences = await SharedPreferences.getInstance();
    await preferences.setInt(birthdayMonthKey, month);
    await preferences.setInt(birthdayDayKey, day);
  }

  static Future<void> clear() async {
    final preferences = await SharedPreferences.getInstance();
    await preferences.remove(birthdayMonthKey);
    await preferences.remove(birthdayDayKey);
  }

  static bool _isValidMonthDay(int? month, int? day) {
    if (month == null || day == null || month < 1 || month > 12) {
      return false;
    }
    final date = DateTime(2000, month, day);
    return date.month == month && date.day == day;
  }
}
