import 'package:flutter/foundation.dart';

import '../database/app_database.dart';
import '../models/daily_question.dart';
import '../models/journal_entry.dart';
import '../services/question_service.dart';

class JournalProvider extends ChangeNotifier {
  JournalProvider({AppDatabase? database, QuestionService? questionService})
      : _database = database ?? AppDatabase.instance,
        _questionService =
            questionService ?? QuestionService(database: database);

  final AppDatabase _database;
  final QuestionService _questionService;
  JournalEntry? _entry;
  DailyQuestion? _dailyQuestion;
  String? _loadedDate;
  String _draftQuestionText = JournalEntry.defaultQuestionText;
  bool _isLoading = false;
  bool _isSaving = false;
  String? _error;
  bool _disposed = false;
  int _loadRequest = 0;

  JournalEntry? get entry => _entry;
  DailyQuestion? get dailyQuestion => _dailyQuestion;
  String? get loadedDate => _loadedDate;
  String get questionText => _draftQuestionText;
  bool get isLoading => _isLoading;
  bool get isSaving => _isSaving;
  String? get error => _error;

  Future<void> loadJournal(DateTime date) async {
    final request = ++_loadRequest;
    final key = JournalEntry.dateKey(date);
    _loadedDate = key;
    _isLoading = true;
    _error = null;
    _notifyListeners();

    try {
      final entry = await _database.getJournalByDate(date);
      final savedQuestion = await _questionService.getSavedQuestion(date);
      final resolved = savedQuestion == null
          ? await _questionService.resolveQuestion(date)
          : null;
      if (request != _loadRequest) return;
      _entry = entry;
      _dailyQuestion = savedQuestion;
      _draftQuestionText = savedQuestion?.questionText ??
          (resolved?.questionText ??
              JournalEntry.normalizeQuestionText(entry?.questionText));
    } catch (error) {
      if (request != _loadRequest) return;
      _entry = null;
      _dailyQuestion = null;
      _draftQuestionText = JournalEntry.defaultQuestionText;
      _error = error.toString();
    } finally {
      if (request == _loadRequest) {
        _isLoading = false;
        _notifyListeners();
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
    _notifyListeners();
    try {
      final existing = _entry ?? await _database.getJournalByDate(date);
      final dailyQuestion = await _questionService.saveUserQuestion(
        date: date,
        questionText: questionText,
      );
      final now = DateTime.now();
      final entry = JournalEntry(
        id: existing?.id,
        entryDate: JournalEntry.dateKey(date),
        questionId: dailyQuestion.id,
        // Kept nullable for backup compatibility. New writes use question_id
        // and daily_question as the source of truth.
        questionText: null,
        questionAnswer: _optionalText(questionAnswer),
        content: _optionalText(content),
        createdAt: existing?.createdAt ?? now,
        updatedAt: now,
      );
      final saved = await _database.saveJournal(entry);
      _entry = saved;
      _dailyQuestion = dailyQuestion;
      _loadedDate = saved.entryDate;
      _draftQuestionText =
          JournalEntry.normalizeQuestionText(saved.questionText);
      _notifyListeners();
      return saved;
    } finally {
      _isSaving = false;
      _notifyListeners();
    }
  }

  Future<void> updateQuestion(String value) async {
    _draftQuestionText = JournalEntry.normalizeQuestionText(value);

    final date = _loadedDate == null ? null : DateTime.parse(_loadedDate!);
    if (date == null) {
      _notifyListeners();
      return;
    }
    _dailyQuestion = await _questionService.saveUserQuestion(
      date: date,
      questionText: _draftQuestionText,
    );
    final current = _entry;
    if (current != null) {
      _entry = await _database.saveJournal(
        JournalEntry(
          id: current.id,
          entryDate: current.entryDate,
          questionId: _dailyQuestion!.id,
          questionText: null,
          questionAnswer: current.questionAnswer,
          content: current.content,
          createdAt: current.createdAt,
          updatedAt: DateTime.now(),
        ),
      );
    }
    _notifyListeners();
  }

  void _notifyListeners() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  static String? _optionalText(String value) {
    final normalized = value.trim();
    return normalized.isEmpty ? null : value;
  }
}
