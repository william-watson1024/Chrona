import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

import '../providers/focus_settings_provider.dart';

/// Owns the local-notification channels used by focus and break sessions.
///
/// There is intentionally only one notification id: CHRONA has one active
/// focus session at a time, and reusing the id makes replacing an old
/// schedule explicit and reliable.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int focusNotificationId = 1001;
  static const String _defaultChannelId = 'chrona_default_alerts_v2';
  static const String _ringChannelId = 'chrona_reminder_ring_v1';
  static const String _vibrateChannelId = 'chrona_reminder_vibrate_v1';
  static const String _ringAndVibrateChannelId =
      'chrona_reminder_ring_vibrate_v1';
  static const List<String> _legacyChannelIds = <String>[
    'chrona_focus_progress_v1',
    'chrona_break_progress_v1',
    'chrona_reminder_service_v1',
    'chrona_default_alerts_v1',
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
  static const String _stopReminderActionId = 'stop_focus_reminder';
  static const AndroidNotificationSound _systemDefaultSound =
      UriAndroidNotificationSound(
          'content://settings/system/notification_sound');

  final FlutterLocalNotificationsPlugin _plugin =
      FlutterLocalNotificationsPlugin();

  Future<void>? _initialization;
  Future<void> _operation = Future<void>.value();
  bool _initialized = false;

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

      await _plugin.initialize(
        settings,
        onDidReceiveNotificationResponse: _handleNotificationResponse,
        onDidReceiveBackgroundNotificationResponse: notificationTapBackground,
      );

      final android = _plugin.resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();
      // Android notification channels are persistent and immutable. Remove
      // channels from earlier CHRONA builds, including the old v3 collision
      // where the focus and break channel IDs overlapped after an upgrade.
      for (final channelId in _legacyChannelIds) {
        await android?.deleteNotificationChannel(channelId);
      }
      await android?.createNotificationChannel(
        const AndroidNotificationChannel(
          _defaultChannelId,
          '计时提醒',
          description: '使用系统默认提醒音和震动',
          importance: Importance.high,
          playSound: true,
          sound: _systemDefaultSound,
          enableVibration: true,
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

  /// Requests notification permission and, when needed, exact-alarm access.
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
      if (notificationsEnabled == false) {
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
      if (!_initialized || !endsAt.isAfter(DateTime.now())) return;

      await requestPermission();
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannelId,
          title,
          channelDescription: 'CHRONA ${isBreak ? '休息' : '专注'}计时',
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

      // The end reminder deliberately reuses this id. When Android delivers
      // the scheduled notification, it replaces the non-dismissible ongoing
      // countdown with the completion reminder.
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
      endsAt: endsAt,
      plannedDurationSeconds: null,
      payload: 'break_finished',
      requestExactAlarmPermission: requestExactAlarmPermission,
    );
  }

  Future<void> _scheduleEnd({
    required String title,
    required String Function(String durationLabel) body,
    required DateTime endsAt,
    required int? plannedDurationSeconds,
    required String payload,
    required bool requestExactAlarmPermission,
  }) {
    return _enqueue(() async {
      await initialize();
      if (!_initialized || !endsAt.isAfter(DateTime.now())) return;

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
      final playSound = reminderMode != ReminderMode.vibrate;
      final enableVibration = reminderMode != ReminderMode.ring;

      final durationLabel = plannedDurationSeconds == null
          ? ''
          : _formatDuration(plannedDurationSeconds);
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          _defaultChannelId,
          title,
          channelDescription: 'CHRONA $title',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          sound: _systemDefaultSound,
          enableVibration: true,
          ongoing: true,
          autoCancel: false,
          category: AndroidNotificationCategory.alarm,
          visibility: NotificationVisibility.public,
          actions: const <AndroidNotificationAction>[
            AndroidNotificationAction(
              _stopReminderActionId,
              '停止提醒',
              cancelNotification: true,
            ),
          ],
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
        await _plugin.cancel(focusNotificationId);
      } catch (error, stackTrace) {
        debugPrint('CHRONA notification cancellation failed: $error');
        debugPrintStack(stackTrace: stackTrace);
      }
    });
  }

  Future<void> _handleNotificationResponse(
    NotificationResponse response,
  ) async {
    if (response.actionId == _stopReminderActionId) {
      await cancelFocusEnd();
    }
    // Tapping the notification body launches/resumes the Flutter activity.
    // FocusProvider observes the resumed lifecycle and moves to finished;
    // FocusScreen then opens the completion/record page.
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

@pragma('vm:entry-point')
void notificationTapBackground(NotificationResponse response) {
  // The action is declared with cancelNotification: true, so Android removes
  // the displayed reminder even when this callback runs in a background
  // isolate. No custom background service is needed.
}
