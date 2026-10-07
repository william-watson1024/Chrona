import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../database/app_database.dart';
import 'birthday_settings.dart';

class DataTransferService {
  DataTransferService({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;

  Future<Uri?> exportData() async {
    final payload = await _database.exportData();
    final preferences = await SharedPreferences.getInstance();
    final breakDuration = preferences.getInt('break_duration_seconds');
    final reminderMode = preferences.getString('reminder_mode');
    final birthdayMonth = preferences.getInt(BirthdaySettings.birthdayMonthKey);
    final birthdayDay = preferences.getInt(BirthdaySettings.birthdayDayKey);
    if (breakDuration != null ||
        reminderMode != null ||
        birthdayMonth != null ||
        birthdayDay != null) {
      payload['settings'] = {
        if (breakDuration != null) 'break_duration_seconds': breakDuration,
        if (reminderMode != null) 'reminder_mode': reminderMode,
        if (birthdayMonth != null) 'birthday_month': birthdayMonth,
        if (birthdayDay != null) 'birthday_day': birthdayDay,
      };
    }

    final bytes = Uint8List.fromList(
      utf8.encode(const JsonEncoder.withIndent('  ').convert(payload)),
    );
    final date = DateTime.now();
    final fileName =
        'chrona_backup_${date.year}${date.month.toString().padLeft(2, '0')}${date.day.toString().padLeft(2, '0')}.json';
    final path = await FilePicker.platform.saveFile(
      dialogTitle: '\u5bfc\u51fa\u62fe\u5e74\u6570\u636e',
      fileName: fileName,
      bytes: bytes,
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (path == null) return null;
    return Uri.tryParse(path);
  }

  Future<Map<String, dynamic>?> pickBackup() async {
    final result = await FilePicker.platform.pickFiles(
      dialogTitle: '\u5bfc\u5165\u62fe\u5e74\u6570\u636e',
      type: FileType.custom,
      allowedExtensions: ['json'],
      withData: true,
    );
    if (result == null || result.files.isEmpty) return null;

    final bytes = result.files.single.bytes;
    if (bytes == null) {
      throw const FormatException(
          '\u65e0\u6cd5\u8bfb\u53d6\u5907\u4efd\u6587\u4ef6');
    }
    final decoded = jsonDecode(utf8.decode(bytes));
    if (decoded is! Map ||
        decoded['format'] != 'chrona_backup' ||
        decoded['version'] != 1) {
      throw const FormatException(
          '\u4e0d\u662f\u6709\u6548\u7684\u62fe\u5e74\u6570\u636e\u6587\u4ef6');
    }
    return Map<String, dynamic>.from(decoded);
  }

  Future<void> importData(Map<String, dynamic> payload) async {
    await _database.importData(payload);

    final settings = payload['settings'];
    if (settings is Map) {
      final breakDuration = settings['break_duration_seconds'];
      if (breakDuration is num && breakDuration.toInt() > 0) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setInt(
          'break_duration_seconds',
          breakDuration.toInt(),
        );
      }
      final reminderMode = settings['reminder_mode'];
      if (reminderMode is String &&
          const <String>{
            'ring',
            'vibrate',
            'ringAndVibrate',
            'notificationOnly',
          }
              .contains(reminderMode)) {
        final preferences = await SharedPreferences.getInstance();
        await preferences.setString('reminder_mode', reminderMode);
      }
      final birthdayMonth = settings['birthday_month'];
      final birthdayDay = settings['birthday_day'];
      if (birthdayMonth is num && birthdayDay is num) {
        await BirthdaySettings.save(
          month: birthdayMonth.toInt(),
          day: birthdayDay.toInt(),
        );
      }
    }
  }
}
