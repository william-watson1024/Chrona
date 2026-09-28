import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/focus_session.dart';

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
    final now = DateTime.now();
    final todayStart = DateTime(now.year, now.month, now.day);
    final tomorrowStart = todayStart.add(const Duration(days: 1));
    final todaySessions = _sessions.where((session) {
      return !session.startedAt.isBefore(todayStart) &&
          session.startedAt.isBefore(tomorrowStart);
    });

    var actualSeconds = 0;
    for (final session in todaySessions) {
      actualSeconds += session.actualDurationSeconds;
    }
    return actualSeconds / Duration.secondsPerHour;
  }

  List<FocusSession> sessionsBetween(DateTime start, DateTime end) {
    return _sessions
        .where((session) =>
            !session.startedAt.isBefore(start) &&
            session.startedAt.isBefore(end))
        .toList(growable: false);
  }

  List<FocusSession> sessionsForDay(DateTime date) {
    final start = DateTime(date.year, date.month, date.day);
    return sessionsBetween(start, start.add(const Duration(days: 1)));
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

  void _sortSessions() {
    _sessions.sort((a, b) {
      final byStartedAt = b.startedAt.compareTo(a.startedAt);
      if (byStartedAt != 0) return byStartedAt;
      return (b.id ?? 0).compareTo(a.id ?? 0);
    });
  }
}
