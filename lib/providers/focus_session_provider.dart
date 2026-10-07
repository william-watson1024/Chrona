import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/focus_session.dart';
import '../utils/focus_formatters.dart';

class FocusSessionProvider extends ChangeNotifier {
  static final Map<String, Future<FocusSession?>> _sessionSaveQueue = {};

  FocusSessionProvider({AppDatabase? database})
      : _database = database ?? AppDatabase.instance,
        _sessions = [];

  FocusSessionProvider.inMemory([List<FocusSession>? sessions])
      : _database = AppDatabase.instance,
        _sessions = List<FocusSession>.from(sessions ?? const []),
        _isLoaded = true,
        _isInMemory = true;

  final AppDatabase _database;
  final List<FocusSession> _sessions;
  bool _isLoaded = false;
  bool _isInMemory = false;
  bool _isSaving = false;
  int _nextInMemoryId = -1;

  List<FocusSession> get sessions => List.unmodifiable(_sessions);
  bool get isLoading => !_isLoaded;
  bool get isSaving => _isSaving;

  double get todayFocusDurationHours {
    return focusDurationSecondsForDay(DateTime.now()) / Duration.secondsPerHour;
  }

  int focusDurationSecondsForDay(DateTime date) {
    return sessionsForDay(date).fold<int>(
      0,
      (total, session) => total + session.actualDurationSeconds,
    );
  }

  int completedFocusCountForDay(DateTime date) {
    return sessionsForDay(date)
        .where((session) => session.status == FocusSessionStatus.completed)
        .length;
  }

  List<FocusSession> sessionsBetween(DateTime start, DateTime end) {
    return _sessions
        .where((session) =>
            !session.startedAt.isBefore(start) &&
            session.startedAt.isBefore(end))
        .toList(growable: false);
  }

  List<FocusSession> sessionsForDay(DateTime date) {
    final start = startOfLocalDay(date);
    final end = start.add(const Duration(days: 1));
    return _sessions.where((session) {
      final localStartedAt = session.startedAt.toLocal();
      return !localStartedAt.isBefore(start) && localStartedAt.isBefore(end);
    }).toList(growable: false);
  }

  Future<void> loadSessions() async {
    if (_isLoaded) return;

    try {
      _sessions
        ..clear()
        ..addAll(await _database.loadFocusSessions());
      _sortSessions();
    } finally {
      _isLoaded = true;
      notifyListeners();
    }
  }

  Future<FocusSession?> saveSession(FocusSession session) async {
    if (_isSaving) return null;
    _isSaving = true;
    notifyListeners();

    try {
      final savedSession = _isInMemory
          ? session.copyWith(id: _nextInMemoryId--)
          : await _database.insertFocusSession(session);
      _sessions.add(savedSession);
      _sortSessions();
      notifyListeners();
      return savedSession;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<FocusSession?> saveSessionIfAbsent(FocusSession session) async {
    final key = _sessionKey(session);
    final pending = _sessionSaveQueue[key];
    if (pending != null) return pending;

    final operation = _saveSessionIfAbsent(session);
    _sessionSaveQueue[key] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_sessionSaveQueue[key], operation)) {
        _sessionSaveQueue.remove(key);
      }
    }
  }

  Future<FocusSession?> _saveSessionIfAbsent(FocusSession session) async {
    await loadSessions();
    FocusSession? existing;
    if (_isInMemory) {
      for (final item in _sessions) {
        if (_sameSession(item, session)) {
          existing = item;
          break;
        }
      }
    } else {
      existing = await _database.findFocusSession(
        taskId: session.taskId,
        startedAt: session.startedAt,
        endedAt: session.endedAt,
        status: session.status.databaseValue,
      );
    }
    if (existing != null) {
      final existingSession = existing!;
      if (!_sessions.any((item) => item.id == existingSession.id)) {
        _sessions.add(existingSession);
        _sortSessions();
        notifyListeners();
      }
      return existingSession;
    }
    return saveSession(session);
  }

  String _sessionKey(FocusSession session) =>
      '${session.taskId ?? 'null'}:${session.startedAt.millisecondsSinceEpoch}:'
      '${session.endedAt.millisecondsSinceEpoch}:${session.status.databaseValue}';

  bool _sameSession(FocusSession first, FocusSession second) =>
      first.taskId == second.taskId &&
      first.startedAt.isAtSameMomentAs(second.startedAt) &&
      first.endedAt.isAtSameMomentAs(second.endedAt) &&
      first.status == second.status;

  Future<FocusSession?> updateSessionNote(
    FocusSession session,
    String? note,
  ) async {
    final id = session.id;
    if (id == null) return null;

    final normalizedNote = note?.trim();
    final updated = session.copyWithNote(
      normalizedNote == null || normalizedNote.isEmpty ? null : normalizedNote,
    );
    if (!_isInMemory) {
      await _database.updateFocusSessionNote(id, updated.note);
    }

    final index = _sessions.indexWhere((item) => item.id == id);
    if (index >= 0) _sessions[index] = updated;
    notifyListeners();
    return updated;
  }

  Future<FocusSession?> updateSessionDetails(
    FocusSession session, {
    required String taskTitleSnapshot,
    required String? note,
  }) async {
    final id = session.id;
    if (id == null) return null;

    final normalizedNote = note?.trim();
    final updated = session.copyWithTitleAndNote(
      title: taskTitleSnapshot,
      note: normalizedNote == null || normalizedNote.isEmpty
          ? null
          : normalizedNote,
    );
    if (!_isInMemory) {
      await _database.updateFocusSessionDetails(
        id,
        taskTitleSnapshot: updated.taskTitleSnapshot,
        note: updated.note,
      );
    }

    final index = _sessions.indexWhere((item) => item.id == id);
    if (index >= 0) _sessions[index] = updated;
    notifyListeners();
    return updated;
  }

  void _sortSessions() {
    _sessions.sort((a, b) {
      final byStartedAt = b.startedAt.compareTo(a.startedAt);
      if (byStartedAt != 0) return byStartedAt;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }
}
