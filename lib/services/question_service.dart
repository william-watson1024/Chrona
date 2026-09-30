import 'dart:math';

import '../database/app_database.dart';
import '../models/daily_question.dart';
import '../models/journal_entry.dart';
import '../repositories/question_repository.dart';
import 'question_resolver.dart';

class QuestionService {
  QuestionService({
    AppDatabase? database,
    QuestionRepository? repository,
    Random? random,
  })  : _database = database ?? AppDatabase.instance,
        _resolver = QuestionResolver(
          repository: repository ?? QuestionRepository.shared,
          database: database ?? AppDatabase.instance,
        ),
        _repository = repository ?? QuestionRepository.shared,
        _random = random ?? Random();

  final AppDatabase _database;
  final QuestionResolver _resolver;
  final QuestionRepository _repository;
  final Random _random;
  final List<String> _recentRandomQuestionIds = <String>[];

  Future<QuestionDefinition?> resolveQuestion(DateTime date) =>
      _resolver.resolveQuestion(date);

  Future<DailyQuestion?> getSavedQuestion(DateTime date) {
    return _database.getDailyQuestionByDate(date);
  }

  Future<DailyQuestion> ensureQuestion(
    DateTime date, {
    QuestionDefinition? definition,
  }) async {
    final existing = await _database.getDailyQuestionByDate(date);
    if (existing != null) return existing;

    final resolved = definition ?? await _resolver.resolveDefaultQuestion(date);
    final fallback = resolved?.questionText ?? JournalEntry.defaultQuestionText;
    final now = DateTime.now();
    return _database.saveDailyQuestion(
      DailyQuestion(
        entryDate: JournalEntry.dateKey(date),
        sourceType: resolved?.sourceType ?? 'CUSTOM',
        sourceKey: resolved?.sourceKey,
        originalQuestionText: fallback,
        questionText: fallback,
        isModified: false,
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  Future<DailyQuestion> saveUserQuestion({
    required DateTime date,
    required String questionText,
  }) async {
    final normalized = JournalEntry.normalizeQuestionText(questionText);
    final existing = await _database.getDailyQuestionByDate(date);
    final question = existing ?? await ensureQuestion(date);
    if (existing != null && normalized == question.questionText) {
      return question;
    }

    if (normalized == question.originalQuestionText) {
      final defaultDefinition = await _resolver.resolveDefaultQuestion(date);
      return _database.saveDailyQuestion(
        question.copyWith(
          sourceType: defaultDefinition?.sourceType ?? question.sourceType,
          sourceKey: defaultDefinition?.sourceKey ?? question.sourceKey,
          questionText: normalized,
          isModified: false,
          updatedAt: DateTime.now(),
        ),
      );
    }

    return _database.saveDailyQuestion(
      question.copyWith(
        questionText: normalized,
        sourceType: 'CUSTOM',
        sourceKey: 'custom',
        isModified: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<DailyQuestion> replaceWithRandomQuestion(DateTime date) async {
    final current = await ensureQuestion(date);
    final pool = await _repository.randomQuestions();
    final selected = selectRandomQuestion(
      pool: pool,
      currentQuestion: current.questionText,
    );

    return _database.saveDailyQuestion(
      current.copyWith(
        sourceType: 'RANDOM',
        sourceKey: 'random:${selected.id}',
        questionText: selected.questionText,
        isModified: true,
        updatedAt: DateTime.now(),
      ),
    );
  }

  RandomQuestionDefinition selectRandomQuestion({
    required List<RandomQuestionDefinition> pool,
    required String currentQuestion,
  }) {
    final excludedIds = _recentRandomQuestionIds.toSet();
    final candidates = pool
        .where((question) =>
            question.questionText != currentQuestion &&
            !excludedIds.contains(question.id))
        .toList(growable: false);
    final fallbackCandidates = pool
        .where((question) => question.questionText != currentQuestion)
        .toList(growable: false);
    final available = candidates.isNotEmpty ? candidates : fallbackCandidates;
    if (available.isEmpty) {
      throw StateError('No different random question is available');
    }

    final selected = available[_random.nextInt(available.length)];
    _recentRandomQuestionIds
      ..remove(selected.id)
      ..add(selected.id);
    if (_recentRandomQuestionIds.length > 20) {
      _recentRandomQuestionIds.removeRange(
        0,
        _recentRandomQuestionIds.length - 20,
      );
    }
    return selected;
  }

  Future<DailyQuestion> restoreDefaultQuestion(DateTime date) async {
    final existing = await _database.getDailyQuestionByDate(date);
    final resolved = await _resolver.resolveDefaultQuestion(date);
    final question =
        existing ?? await ensureQuestion(date, definition: resolved);
    final text = question.originalQuestionText;
    return _database.saveDailyQuestion(
      question.copyWith(
        sourceType: resolved?.sourceType ?? question.sourceType,
        sourceKey: resolved?.sourceKey ?? question.sourceKey,
        questionText: text,
        isModified: false,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
