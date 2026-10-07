import 'dart:async';
import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/task.dart';
import '../services/notification_service.dart';

enum FocusTimerStatus { idle, running, paused, finished, cancelled }

enum FocusMode { focus, rest }

abstract final class FocusTimerDurations {
  static const tenSeconds = 10;
  static const thirtySeconds = 30;
  static const oneMinute = 60;
  static const newTaskDefault = 15 * 60;
  static const pomodoro = 25 * 60;
}

class FocusSessionResult {
  const FocusSessionResult({
    required this.task,
    required this.startedAt,
    required this.endedAt,
    required this.plannedDurationSeconds,
    required this.actualDurationSeconds,
    required this.status,
  });

  final Task task;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedDurationSeconds;
  final int actualDurationSeconds;
  final FocusTimerStatus status;
}

class FocusProvider extends ChangeNotifier with WidgetsBindingObserver {
  static const _activeSessionKey = 'chrona_active_focus_session_v1';
  static Future<void> _persistenceQueue = Future<void>.value();
  static int _persistenceRevision = 0;

  FocusProvider({
    required this.task,
    this.plannedDurationSeconds = FocusTimerDurations.pomodoro,
    this.mode = FocusMode.focus,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        _persistenceEnabled = now == null,
        remainingSeconds = plannedDurationSeconds {
    WidgetsBinding.instance.addObserver(this);
  }

  /// Restores the one active focus/break session, if one was persisted.
  ///
  /// The task snapshot is kept with the timer so the session can be restored
  /// even when the task list has not finished loading yet or the task was
  /// edited while the app process was gone.
  static Future<FocusProvider?> restore({Task? task}) async {
    final preferences = await SharedPreferences.getInstance();
    final encoded = preferences.getString(_activeSessionKey);
    if (encoded == null || encoded.isEmpty) return null;

    try {
      final decoded = jsonDecode(encoded);
      if (decoded is! Map) throw const FormatException('Invalid timer state');
      final snapshot = Map<String, dynamic>.from(decoded);
      final taskMap = snapshot['task'];
      if (taskMap is! Map) throw const FormatException('Missing timer task');

      final storedTask = Task.fromMap(Map<String, Object?>.from(taskMap));
      final restoredTask = task ?? storedTask;
      final plannedDuration = _readPersistedInt(
        snapshot['planned_duration_seconds'],
      );
      final startedAt = _readPersistedDateTime(snapshot['started_at']);
      final status = snapshot['status'];
      final mode = snapshot['mode'];
      if (plannedDuration == null ||
          plannedDuration <= 0 ||
          startedAt == null) {
        throw const FormatException('Invalid timer timestamps');
      }
      if (status != 'running' &&
          status != 'paused' &&
          status != 'finished' &&
          status != 'cancelled') {
        throw const FormatException('Invalid timer status');
      }
      if (mode != 'focus' && mode != 'rest') {
        throw const FormatException('Invalid timer mode');
      }

      final provider = FocusProvider(
        task: restoredTask,
        plannedDurationSeconds: plannedDuration,
        mode: mode == 'rest' ? FocusMode.rest : FocusMode.focus,
      );
      provider.startedAt = startedAt;
      provider.endsAt = _readPersistedDateTime(snapshot['ends_at']);
      provider.pausedAt = _readPersistedDateTime(snapshot['paused_at']);
      provider._totalPausedMilliseconds =
          _readPersistedInt(snapshot['total_paused_ms']) ?? 0;
      provider.pausedRemainingSeconds = _readPersistedInt(
        snapshot['paused_remaining_seconds'],
      );
      provider._pausedRemainingMilliseconds = _readPersistedInt(
        snapshot['paused_remaining_ms'],
      );
      provider.isCountUp = snapshot['is_count_up'] == true;
      provider.status = status == 'paused'
          ? FocusTimerStatus.paused
          : status == 'finished'
              ? FocusTimerStatus.finished
              : status == 'cancelled'
                  ? FocusTimerStatus.cancelled
                  : FocusTimerStatus.running;
      provider.endedAt = _readPersistedDateTime(snapshot['ended_at']);

      if (provider.isRunning) {
        if (provider.endsAt == null) {
          throw const FormatException('Running timer has no end time');
        }
        provider._refreshFromClock(notify: false);
        if (provider.isRunning) {
          provider._startTicker();
          provider._scheduleNotification();
        }
      } else if (provider.isPaused) {
        final pausedRemaining = provider.pausedRemainingSeconds;
        if (pausedRemaining == null || pausedRemaining < 0) {
          throw const FormatException('Paused timer has no remaining time');
        }
        provider.remainingSeconds = pausedRemaining;
      } else {
        if (provider.isBreak || provider.endedAt == null) {
          throw const FormatException('Invalid finished timer state');
        }
        provider.remainingSeconds = 0;
      }

      return provider;
    } catch (_) {
      await clearPersistedState();
      return null;
    }
  }

  static Future<void> clearPersistedState() async {
    final revision = ++_persistenceRevision;
    _persistenceQueue = _persistenceQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (revision != _persistenceRevision) return;
      await preferences.remove(_activeSessionKey);
    }).catchError((_) {});
    await _persistenceQueue;
  }

  final Task task;
  final int plannedDurationSeconds;
  final FocusMode mode;
  final DateTime Function() _now;
  final bool _persistenceEnabled;

  DateTime? startedAt;
  DateTime? endsAt;
  DateTime? pausedAt;
  DateTime? endedAt;
  int _totalPausedMilliseconds = 0;
  int remainingSeconds;
  int? pausedRemainingSeconds;
  int? _pausedRemainingMilliseconds;
  FocusTimerStatus status = FocusTimerStatus.idle;
  bool isCountUp = false;

  Timer? _ticker;

  bool get isRunning => status == FocusTimerStatus.running;
  bool get isPaused => status == FocusTimerStatus.paused;
  bool get isFinished => status == FocusTimerStatus.finished;
  bool get isBreak => mode == FocusMode.rest;

  int get displaySeconds {
    if (!isCountUp) return remainingSeconds;
    final elapsed = plannedDurationSeconds - remainingSeconds;
    return elapsed < 0 ? 0 : elapsed;
  }

  void toggleTimerDisplay() {
    isCountUp = !isCountUp;
    notifyListeners();
  }

  int get actualDurationSeconds {
    final start = startedAt;
    final end = endedAt;
    if (start == null || end == null) return 0;
    var pausedMilliseconds = _totalPausedMilliseconds;
    final pauseStartedAt = pausedAt;
    if (pauseStartedAt != null) {
      pausedMilliseconds += end.difference(pauseStartedAt).inMilliseconds;
    }
    final seconds =
        (end.difference(start).inMilliseconds - pausedMilliseconds) ~/ 1000;
    return seconds < 0 ? 0 : seconds;
  }

  FocusSessionResult get sessionResult {
    final start = startedAt;
    final end = endedAt;
    if (start == null || end == null) {
      throw StateError('Focus session has not ended');
    }
    return FocusSessionResult(
      task: task,
      startedAt: start,
      endedAt: end,
      plannedDurationSeconds: plannedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      status: status,
    );
  }

  void start() {
    if (status != FocusTimerStatus.idle) return;
    startedAt = _now();
    endsAt = startedAt!.add(Duration(seconds: plannedDurationSeconds));
    pausedAt = null;
    pausedRemainingSeconds = null;
    status = FocusTimerStatus.running;
    _refreshFromClock();
    _startTicker();
    _persistActiveState();
    _scheduleNotification();
    notifyListeners();
  }

  void pause() {
    if (status != FocusTimerStatus.running) return;
    _refreshFromClock();
    if (status != FocusTimerStatus.running) return;
    pausedAt = _now();
    _pausedRemainingMilliseconds =
        endsAt!.difference(pausedAt!).inMilliseconds.clamp(0, 1 << 31).toInt();
    pausedRemainingSeconds = (_pausedRemainingMilliseconds! / 1000).ceil();
    _ticker?.cancel();
    _ticker = null;
    endsAt = null;
    status = FocusTimerStatus.paused;
    _persistActiveState();
    unawaited(NotificationService.instance.cancelFocusEnd());
    notifyListeners();
  }

  void resume() {
    if (status != FocusTimerStatus.paused) return;
    final pauseStartedAt = pausedAt;
    if (pauseStartedAt != null) {
      _totalPausedMilliseconds +=
          _now().difference(pauseStartedAt).inMilliseconds;
    }
    remainingSeconds = pausedRemainingSeconds ?? remainingSeconds;
    final remainingMilliseconds =
        _pausedRemainingMilliseconds ?? remainingSeconds * 1000;
    endsAt = _now().add(Duration(milliseconds: remainingMilliseconds));
    pausedAt = null;
    pausedRemainingSeconds = null;
    _pausedRemainingMilliseconds = null;
    status = FocusTimerStatus.running;
    _startTicker();
    _persistActiveState();
    _scheduleNotification();
    notifyListeners();
  }

  void cancel() {
    if (status != FocusTimerStatus.running &&
        status != FocusTimerStatus.paused) {
      return;
    }
    if (status == FocusTimerStatus.running) _refreshFromClock();
    if (status != FocusTimerStatus.running &&
        status != FocusTimerStatus.paused) {
      return;
    }
    endedAt = _now();
    if (pausedAt != null) {
      _totalPausedMilliseconds += endedAt!.difference(pausedAt!).inMilliseconds;
      pausedAt = null;
    }
    status = FocusTimerStatus.cancelled;
    _ticker?.cancel();
    _ticker = null;
    _persistActiveState();
    unawaited(NotificationService.instance.cancelFocusEnd());
    notifyListeners();
  }

  void skipBreak() {
    if (!isBreak ||
        (status != FocusTimerStatus.running &&
            status != FocusTimerStatus.paused)) {
      return;
    }
    if (status == FocusTimerStatus.running) _refreshFromClock();
    if (status != FocusTimerStatus.running &&
        status != FocusTimerStatus.paused) {
      return;
    }
    endedAt = _now();
    remainingSeconds = 0;
    status = FocusTimerStatus.finished;
    _ticker?.cancel();
    _ticker = null;
    _clearPersistedState();
    unawaited(NotificationService.instance.cancelFocusEnd());
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    _refreshFromClock();
    if (isRunning) {
      // Exact-alarm access may have been granted from Android's settings
      // screen after the first schedule fell back to an inexact alarm.
      // Replacing the schedule on resume applies the newly granted access.
      _scheduleNotification(requestExactAlarmPermission: false);
    }
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshFromClock();
    });
  }

  void _refreshFromClock({bool notify = true}) {
    if (status != FocusTimerStatus.running || endsAt == null) return;
    final end = endsAt!;
    final millisecondsRemaining = end.difference(_now()).inMilliseconds;
    if (millisecondsRemaining <= 0) {
      remainingSeconds = 0;
      // A late UI tick must never turn a 25-minute session into a 28-minute
      // session. The scheduled end timestamp is the canonical completion time.
      endedAt = end;
      status = FocusTimerStatus.finished;
      _ticker?.cancel();
      _ticker = null;
      if (isBreak) {
        _clearPersistedState();
      } else {
        _persistActiveState();
      }
      if (notify) notifyListeners();
      return;
    }

    remainingSeconds = (millisecondsRemaining / 1000).ceil();
    if (notify) notifyListeners();
  }

  void _scheduleNotification({bool requestExactAlarmPermission = true}) {
    final end = endsAt;
    if (end == null) return;
    unawaited(_scheduleAfterPersisting(end, requestExactAlarmPermission));
  }

  Future<void> _scheduleAfterPersisting(
    DateTime end,
    bool requestExactAlarmPermission,
  ) async {
    await _persistenceQueue;
    if ((status != FocusTimerStatus.running &&
            status != FocusTimerStatus.finished) ||
        endsAt != end) {
      return;
    }
    unawaited(NotificationService.instance.showOngoingTimer(
      endsAt: end,
      title: isBreak ? '拾年 · 休息中' : '拾年 · 专注中',
      body: isBreak ? '短休息' : task.title,
      isBreak: isBreak,
    ));
    if (isBreak) {
      unawaited(NotificationService.instance.scheduleBreakEnd(
        endsAt: end,
        requestExactAlarmPermission: requestExactAlarmPermission,
      ));
      return;
    }
    unawaited(NotificationService.instance.scheduleFocusEnd(
      endsAt: end,
      taskTitle: task.title,
      plannedDurationSeconds: plannedDurationSeconds,
      requestExactAlarmPermission: requestExactAlarmPermission,
    ));
  }

  @override
  void dispose() {
    _ticker?.cancel();
    // Provider/UI disposal must not cancel a user-started timer. The timer is
    // persisted independently and the Android notification owns its schedule.
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  void _persistActiveState() {
    if (!_persistenceEnabled || startedAt == null) {
      return;
    }

    final snapshot = <String, dynamic>{
      'version': 1,
      'status': status.name,
      'mode': mode.name,
      'planned_duration_seconds': plannedDurationSeconds,
      'started_at': startedAt!.millisecondsSinceEpoch,
      'ended_at': endedAt?.millisecondsSinceEpoch,
      'ends_at': endsAt?.millisecondsSinceEpoch,
      'paused_at': pausedAt?.millisecondsSinceEpoch,
      'paused_remaining_seconds': pausedRemainingSeconds,
      'paused_remaining_ms': _pausedRemainingMilliseconds,
      'total_paused_ms': _totalPausedMilliseconds,
      'is_count_up': isCountUp,
      'task': task.toMap(),
    };
    final encoded = jsonEncode(snapshot);
    final revision = ++_persistenceRevision;
    _persistenceQueue = _persistenceQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (revision != _persistenceRevision) return;
      await preferences.setString(_activeSessionKey, encoded);
    }).catchError((_) {});
  }

  void _clearPersistedState() {
    if (!_persistenceEnabled) return;
    final revision = ++_persistenceRevision;
    _persistenceQueue = _persistenceQueue.then((_) async {
      final preferences = await SharedPreferences.getInstance();
      if (revision != _persistenceRevision) return;
      await preferences.remove(_activeSessionKey);
    }).catchError((_) {});
  }
}

int? _readPersistedInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime? _readPersistedDateTime(Object? value) {
  final milliseconds = _readPersistedInt(value);
  return milliseconds == null
      ? null
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
