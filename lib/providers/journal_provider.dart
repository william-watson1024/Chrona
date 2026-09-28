import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/journal_entry.dart';

class JournalProvider extends ChangeNotifier {
  JournalProvider({AppDatabase? database})
      : _database = database ?? AppDatabase.instance;

  final AppDatabase _database;
  JournalEntry? _entry;
  String? _loadedDate;
  String _draftQuestionText = JournalEntry.defaultQuestionText;
  bool _isLoading = false;
  bool _isSaving = false;
  int _loadRequest = 0;

  JournalEntry? get entry => _entry;
  String? get loadedDate => _loadedDate;
  String get questionText => _draftQuestionText;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;

  Future<void> loadJournal(DateTime date) async {
    final request = ++_loadRequest;
    final key = JournalEntry.dateKey(date);
    _loadedDate = key;
    _isLoading = true;
    notifyListeners();

    try {
      final entry = await _database.getJournalByDate(date);
      if (request != _loadRequest) return;
      _entry = entry;
      _draftQuestionText = entry?.questionText?.isNotEmpty == true
          ? entry!.questionText!
          : JournalEntry.defaultQuestionText;
    } finally {
      if (request == _loadRequest) {
        _isLoading = false;
        notifyListeners();
      }
    }
  }

  Future<JournalEntry> saveJournal({
    required DateTime date,
    required String questionText,
    required String questionAnswer,
    required String content,
  }) async {
    if (_isSaving) {
      return _entry ??
          JournalEntry(
            entryDate: JournalEntry.dateKey(date),
            questionText: questionText,
            questionAnswer: _optionalText(questionAnswer),
            content: _optionalText(content),
            createdAt: DateTime.now(),
            updatedAt: DateTime.now(),
          );
    }

    _isSaving = true;
    notifyListeners();
    try {
      final existing = _entry ?? await _database.getJournalByDate(date);
      final now = DateTime.now();
      final entry = JournalEntry(
        id: existing?.id,
        entryDate: JournalEntry.dateKey(date),
        questionText: questionText.trim().isEmpty
            ? JournalEntry.defaultQuestionText
            : questionText.trim(),
        questionAnswer: _optionalText(questionAnswer),
        content: _optionalText(content),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final saved = await _database.saveJournal(entry);
      _entry = saved;
      _loadedDate = saved.entryDate;
      _draftQuestionText = saved.questionText ?? JournalEntry.defaultQuestionText;
      notifyListeners();
      return saved;
    } finally {
      _isSaving = false;
      notifyListeners();
    }
  }

  Future<void> updateQuestion(String value) async {
    final normalized = value.trim();
    _draftQuestionText = normalized.isEmpty
        ? JournalEntry.defaultQuestionText
        : normalized;

    final current = _entry;
    if (current == null) {
      notifyListeners();
      return;
    }

    final updated = JournalEntry(
      id: current.id,
      entryDate: current.entryDate,
      questionId: current.questionId,
      questionText: _draftQuestionText,
      questionAnswer: current.questionAnswer,
      content: current.content,
      createdAt: current.createdAt,
      updatedAt: DateTime.now(),
    );
    await _database.updateJournal(updated);
    _entry = updated;
    notifyListeners();
  }

  static String? _optionalText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : value;
  }
}
