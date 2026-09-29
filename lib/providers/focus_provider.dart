import 'dart:async';

import 'package:flutter/widgets.dart';

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
  FocusProvider({
    required this.task,
    this.plannedDurationSeconds = FocusTimerDurations.pomodoro,
    this.mode = FocusMode.focus,
    DateTime Function()? now,
  })  : _now = now ?? DateTime.now,
        remainingSeconds = plannedDurationSeconds {
    WidgetsBinding.instance.addObserver(this);
  }

  final Task task;
  final int plannedDurationSeconds;
  final FocusMode mode;
  final DateTime Function() _now;

  DateTime? startedAt;
  DateTime? endsAt;
  DateTime? pausedAt;
  DateTime? endedAt;
  int remainingSeconds;
  int? pausedRemainingSeconds;
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
    final seconds = end.difference(start).inSeconds;
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
    _scheduleNotification();
    notifyListeners();
  }

  void pause() {
    if (status != FocusTimerStatus.running) return;
    _refreshFromClock();
    if (status != FocusTimerStatus.running) return;
    pausedAt = _now();
    pausedRemainingSeconds = remainingSeconds;
    _ticker?.cancel();
    _ticker = null;
    endsAt = null;
    status = FocusTimerStatus.paused;
    unawaited(NotificationService.instance.cancelFocusEnd());
    notifyListeners();
  }

  void resume() {
    if (status != FocusTimerStatus.paused) return;
    remainingSeconds = pausedRemainingSeconds ?? remainingSeconds;
    endsAt = _now().add(Duration(seconds: remainingSeconds));
    pausedAt = null;
    pausedRemainingSeconds = null;
    status = FocusTimerStatus.running;
    _startTicker();
    _scheduleNotification();
    notifyListeners();
  }

  void cancel() {
    if (status != FocusTimerStatus.running &&
        status != FocusTimerStatus.paused) {
      return;
    }
    if (status == FocusTimerStatus.running) _refreshFromClock();
    endedAt = _now();
    status = FocusTimerStatus.cancelled;
    _ticker?.cancel();
    _ticker = null;
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
    unawaited(NotificationService.instance.cancelFocusEnd());
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refreshFromClock();
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _refreshFromClock();
    });
  }

  void _refreshFromClock() {
    if (status != FocusTimerStatus.running || endsAt == null) return;
    final millisecondsRemaining = endsAt!.difference(_now()).inMilliseconds;
    if (millisecondsRemaining <= 0) {
      remainingSeconds = 0;
      endedAt = _now();
      status = FocusTimerStatus.finished;
      _ticker?.cancel();
      _ticker = null;
      notifyListeners();
      return;
    }

    remainingSeconds = (millisecondsRemaining / 1000).ceil();
    notifyListeners();
  }

  void _scheduleNotification() {
    final end = endsAt;
    if (end == null) return;
    if (isBreak) {
      unawaited(NotificationService.instance.scheduleBreakEnd(endsAt: end));
      return;
    }
    unawaited(NotificationService.instance.scheduleFocusEnd(
      endsAt: end,
      taskTitle: task.title,
      plannedDurationSeconds: plannedDurationSeconds,
    ));
  }

  @override
  void dispose() {
    final shouldCancelNotification =
        status == FocusTimerStatus.running || status == FocusTimerStatus.paused;
    _ticker?.cancel();
    if (shouldCancelNotification) {
      unawaited(NotificationService.instance.cancelFocusEnd());
    }
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }
}
