import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/focus_session.dart';
import '../utils/focus_formatters.dart';

class FocusSessionProvider extends ChangeNotifier {
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
    await loadSessions();
    final existing = _sessions.where((item) =>
        item.taskId == session.taskId &&
        item.startedAt.isAtSameMomentAs(session.startedAt) &&
        item.endedAt.isAtSameMomentAs(session.endedAt) &&
        item.status == session.status);
    if (existing.isNotEmpty) return existing.first;
    return saveSession(session);
  }

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
