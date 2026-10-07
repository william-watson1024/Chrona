import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../providers/focus_settings_provider.dart';

/// Schedules focus and break reminders.
///
/// CHRONA has one active timer. Android owns its system alarm and countdown;
/// iOS uses scheduled local notifications.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int focusNotificationId = 1001;
  static const MethodChannel _reminderAlarmChannel =
      MethodChannel('com.chrona.app/reminder_alarm');
  static const String _focusTimerChannelId = 'chrona_focus_timer_v2';
  static const String _defaultChannelId = 'chrona_default_alerts_v3';
  static const String _ringChannelId = 'chrona_reminder_ring_v1';
  static const String _vibrateChannelId = 'chrona_reminder_vibrate_v1';
  static const String _ringAndVibrateChannelId =
      'chrona_reminder_ring_vibrate_v1';
  static const List<String> _legacyChannelIds = <String>[
    _defaultChannelId,
    'chrona_focus_progress_v1',
    'chrona_break_progress_v1',
    'chrona_reminder_service_v1',
    'chrona_default_alerts_v1',
    'chrona_default_alerts_v2',
    _ringChannelId,
    _vibrateChannelId,
    _ringAndVibrateChannelId,
    'chrona_focus_alerts_v1',
    'chrona_focus_alerts_v2',
    'chrona_focus_alerts_v3',
    'chrona_break_alerts_v1',
    'chrona_break_alerts_v2',
    'chrona_break_alerts_v3',
    'chrona_break_alerts_v4',
    'chrona_break_alerts_v5',
    'chrona_focus_alerts_v4',
  ];

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;
  Future<void> _operation = Future<void>.value();
  bool _initialized = false;
  bool _notificationPermissionRequestAttempted = false;

  Future<void> initialize() {
    return _initialization ??= _initialize();
  }

  Future<void> _initialize() async {
    try {
      tz.initializeTimeZones();

      const androidSettings =
          AndroidInitializationSettings('@drawable/ic_launcher');
      const darwinSettings = DarwinInitializationSettings(
        requestAlertPermission: false,
        requestBadgePermission: false,
        requestSoundPermission: false,
      );
      const settings = InitializationSettings(
        android: androidSettings,
        iOS: darwinSettings,
      );

      await _plugin.initialize(settings);

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Remove channels left by earlier builds before creating the dedicated
      // silent countdown channel.
      for (final channelId in _legacyChannelIds) {
        await android?.deleteNotificationChannel(channelId);
      }
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _focusTimerChannelId,
          '专注计时',
          description: '静音显示专注或休息倒计时',
          importance: Importance.low,
          playSound: false,
          enableVibration: false,
          showBadge: false,
        ),
      );
      _initialized = true;
    } catch (error, stackTrace) {
      // Widget tests and unsupported platforms do not have the native plugin
      // registered. Keep the timer usable there while production logs retain
      // the reason notifications were unavailable.
      debugPrint('CHRONA notification initialization failed: $error');
      debugPrintStack(stackTrace: stackTrace);
    }
  }

  /// Requests any permission needed by the active reminder implementation.
  ///
  /// Exact alarms are user-facing timer functionality on Android. If the user
  /// declines the special access, scheduling falls back to an idle-safe
  /// inexact alarm while the timestamp-based timer state remains authoritative.
  Future<bool> requestPermission() async {
    await initialize();
    if (!_initialized) return false;

    try {
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      final notificationsEnabled = await android?.areNotificationsEnabled();
      if (notificationsEnabled == false &&
          !_notificationPermissionRequestAttempted) {
        _notificationPermissionRequestAttempted = true;
        await android?.requestNotificationsPermission();
      }

      final enabledAfterRequest = await android?.areNotificationsEnabled();
      return enabledAfterRequest != false;
    } catch (error, stackTrace) {
      debugPrint('CHRONA notification permission request failed: $error');
      debugPrintStack(stackTrace: stackTrace);
      return false;
    }
  }

  Future<void> showOngoingTimer({
    required DateTime endsAt,
    required String title,
    required String body,
    required bool isBreak,
  }) {
    return _enqueue(() async {
      await initialize();
      if (!_initialized ||
          (Platform.isIOS && !endsAt.isAfter(DateTime.now()))) {
        return;
      }

      final permitted = await requestPermission();
      if (!permitted) return;
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _focusTimerChannelId,
          title,
          channelDescription: '静音显示 CHRONA ${isBreak ? '休息' : '专注'}倒计时',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          silent: true,
          ongoing: true,
          autoCancel: false,
          onlyAlertOnce: true,
          showWhen: true,
          when: endsAt.millisecondsSinceEpoch,
          usesChronometer: true,
          chronometerCountDown: true,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
        ),
        iOS: const DarwinNotificationDetails(presentSound: false),
      );

      await _plugin.cancel(focusNotificationId);
      await _plugin.show(
        focusNotificationId,
        title,
        body,
        notificationDetails,
        payload: isBreak ? 'break_running' : 'focus_running',
      );
    });
  }

  Future<void> scheduleFocusEnd({
    required DateTime endsAt,
    required String taskTitle,
    required int plannedDurationSeconds,
    bool requestExactAlarmPermission = true,
  }) {
    return _scheduleEnd(
      title: '专注完成',
      body: (durationLabel) => '$taskTitle\n本轮 $durationLabel 已结束',
      timerTitle: '拾年 · 专注中',
      timerBody: taskTitle,
      endsAt: endsAt,
      plannedDurationSeconds: plannedDurationSeconds,
      payload: 'focus_finished',
      requestExactAlarmPermission: requestExactAlarmPermission,
    );
  }

  Future<void> scheduleBreakEnd({
    required DateTime endsAt,
    bool requestExactAlarmPermission = true,
  }) {
    return _scheduleEnd(
      title: '休息结束',
      body: (_) => '准备开始下一轮专注',
      timerTitle: '拾年 · 休息中',
      timerBody: '短休息',
      endsAt: endsAt,
      plannedDurationSeconds: null,
      payload: 'break_finished',
      requestExactAlarmPermission: requestExactAlarmPermission,
    );
  }

  Future<void> _scheduleEnd({
    required String title,
    required String Function(String durationLabel) body,
    required String timerTitle,
    required String timerBody,
    required DateTime endsAt,
    required int? plannedDurationSeconds,
    required String payload,
    required bool requestExactAlarmPermission,
  }) {
    return _enqueue(() async {
      await initialize();
      if (!_initialized ||
          (Platform.isIOS && !endsAt.isAfter(DateTime.now()))) {
        return;
      }

      // Request again when the user starts a focus session. Android may have
      // denied the cold-start request, and asking here gives the user another
      // chance before the first reminder is scheduled.
      await requestPermission();

      final preferences = await SharedPreferences.getInstance();
      final configuredMode = preferences.getString(
        FocusSettingsProvider.reminderModeKey,
      );
      final reminderMode = ReminderMode.values.firstWhere(
        (mode) => mode.name == configuredMode,
        orElse: () => FocusSettingsProvider.defaultReminderMode,
      );
      final playSound = reminderMode == ReminderMode.ring ||
          reminderMode == ReminderMode.ringAndVibrate;
      final enableVibration = reminderMode == ReminderMode.vibrate ||
          reminderMode == ReminderMode.ringAndVibrate;

      final durationLabel = plannedDurationSeconds == null
          ? ''
          : _formatDuration(plannedDurationSeconds);
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _focusTimerChannelId,
          title,
          channelDescription: '专注倒计时状态',
          importance: Importance.low,
          priority: Priority.low,
          playSound: false,
          enableVibration: false,
          ongoing: true,
          autoCancel: false,
          silent: true,
          category: AndroidNotificationCategory.progress,
          visibility: NotificationVisibility.public,
        ),
        iOS: DarwinNotificationDetails(presentSound: playSound),
      );

      var scheduleMode = AndroidScheduleMode.inexactAllowWhileIdle;
      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      if (android != null) {
        var canScheduleExact =
            await android.canScheduleExactNotifications() ?? false;
        if (!canScheduleExact && requestExactAlarmPermission) {
          canScheduleExact =
              await android.requestExactAlarmsPermission() ?? false;
        }
        if (canScheduleExact) {
          scheduleMode = AndroidScheduleMode.exactAllowWhileIdle;
          debugPrint('CHRONA: scheduling end reminder with exactAllowWhileIdle');
        } else {
          debugPrint(
            'CHRONA: exact-alarm access unavailable; using inexactAllowWhileIdle. '
            'Android may defer this reminder while the device is idle.',
          );
        }
      }

      if (Platform.isAndroid) {
        try {
          final usedExact = await _reminderAlarmChannel.invokeMethod<bool>(
            'schedule',
            <String, Object>{
              'title': title,
              'body': body(durationLabel),
              'timerTitle': timerTitle,
              'timerBody': timerBody,
              'triggerAtMillis': endsAt.millisecondsSinceEpoch,
              'exact': scheduleMode == AndroidScheduleMode.exactAllowWhileIdle,
              'playSound': playSound,
              'vibrate': enableVibration,
              'promptOnFallback': requestExactAlarmPermission,
            },
          );
          if (usedExact != true) {
            debugPrint(
              'CHRONA: exact alarm unavailable; an inexact allow-while-idle alarm was scheduled. Android may delay it.',
            );
          }
        } catch (error, stackTrace) {
          debugPrint('CHRONA system alarm scheduling failed: $error');
          debugPrintStack(stackTrace: stackTrace);
        }
        return;
      }

      Future<void> schedule(AndroidScheduleMode mode) {
        return _plugin.zonedSchedule(
          focusNotificationId,
          title,
          body(durationLabel),
          tz.TZDateTime.from(endsAt, tz.local),
          notificationDetails,
          androidScheduleMode: mode,
          uiLocalNotificationDateInterpretation:
              UILocalNotificationDateInterpretation.absoluteTime,
          payload: payload,
        );
      }

      try {
        await schedule(scheduleMode);
      } catch (error, stackTrace) {
        // A device can revoke exact-alarm access while the app is running.
        // Keep the reminder instead of losing it altogether.
        if (scheduleMode != AndroidScheduleMode.exactAllowWhileIdle) rethrow;
        debugPrint('CHRONA exact reminder scheduling failed: $error');
        debugPrintStack(stackTrace: stackTrace);
        debugPrint('CHRONA: retrying with inexactAllowWhileIdle');
        await schedule(AndroidScheduleMode.inexactAllowWhileIdle);
      }
    });
  }

  Future<void> cancelFocusEnd() {
    return _enqueue(() async {
      if (!_initialized) return;
      try {
        if (Platform.isAndroid) {
          await _reminderAlarmChannel.invokeMethod<void>('cancel');
        }
        await _plugin.cancel(focusNotificationId);
      } catch (error, stackTrace) {
        debugPrint('CHRONA notification cancellation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  Future<void> _enqueue(Future<void> Function() operation) {
    final next =
        _operation.then((_) => operation(), onError: (_, __) => operation());
    _operation = next.catchError((_) {});
    return next;
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes > 0 && seconds % 60 == 0) return '$minutes 分钟';
    if (minutes > 0) {
      return '$minutes 分 ${seconds % 60} 秒';
    }
    return '$seconds 秒';
  }
}
