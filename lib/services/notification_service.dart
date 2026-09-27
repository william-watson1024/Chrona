import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tz;
import 'package:timezone/timezone.dart' as tz;

/// Owns the single local-notification channel used by focus sessions.
///
/// There is intentionally only one notification id: CHRONA has one active
/// focus session at a time, and reusing the id makes replacing an old
/// schedule explicit and reliable.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  static const int focusNotificationId = 1001;
  // Android channel sound/vibration settings are immutable after creation.
  // Use a new channel id so existing silent installations receive the alert
  // configuration without any native bridge or extra vibration plugin.
  static const String focusChannelId = 'chrona_focus_alerts_v2';
  static const String _stopReminderActionId = 'stop_focus_reminder';

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
      await android?.createNotificationChannel(
        AndroidNotificationChannel(
          focusChannelId,
          '专注完成提醒',
          description: 'CHRONA 番茄钟完成提醒',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 1000, 500, 1000]),
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

  /// Requests the Android 13 notification permission through the plugin.
  /// Exact-alarm access is intentionally not requested: focus reminders use
  /// the plugin's inexact idle-safe schedule mode instead.
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

  Future<void> scheduleFocusEnd({
    required DateTime endsAt,
    required String taskTitle,
    required int plannedDurationSeconds,
  }) {
    return _enqueue(() async {
      await initialize();
      if (!_initialized || !endsAt.isAfter(DateTime.now())) return;

      // Request again when the user starts a focus session. Android may have
      // denied the cold-start request, and asking here gives the user another
      // chance before the first reminder is scheduled.
      await requestPermission();

      // Replacing the same id makes a stale schedule impossible even if a
      // caller starts a new session after an earlier one has ended.
      await _plugin.cancel(focusNotificationId);

      final durationLabel = _formatDuration(plannedDurationSeconds);
      final notificationDetails = NotificationDetails(
        android: AndroidNotificationDetails(
          focusChannelId,
          '专注完成提醒',
          channelDescription: 'CHRONA 番茄钟完成提醒',
          importance: Importance.max,
          priority: Priority.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList(<int>[0, 1000, 500, 1000]),
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
        iOS: const DarwinNotificationDetails(presentSound: true),
      );

      await _plugin.zonedSchedule(
        focusNotificationId,
        '专注完成',
        '$taskTitle\n本轮 $durationLabel 已结束',
        tz.TZDateTime.from(endsAt, tz.local),
        notificationDetails,
        // Deliberately avoid SCHEDULE_EXACT_ALARM. This keeps CHRONA a normal
        // notification app; Android may deliver this a little later while in
        // deep idle, but no special alarm permission is needed.
        androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
        uiLocalNotificationDateInterpretation:
            UILocalNotificationDateInterpretation.absoluteTime,
        payload: 'focus_finished',
      );
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
