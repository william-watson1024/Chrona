import '../database/app_database.dart';
import '../models/daily_question.dart';
import '../models/journal_entry.dart';
import '../repositories/question_repository.dart';
import 'question_resolver.dart';

class QuestionService {
  QuestionService({
    AppDatabase? database,
    QuestionRepository? repository,
  })  : _database = database ?? AppDatabase.instance,
        _resolver = QuestionResolver(
          repository: repository ?? QuestionRepository.shared,
          database: database ?? AppDatabase.instance,
        );

  final AppDatabase _database;
  final QuestionResolver _resolver;

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

    final resolved = definition ?? await resolveQuestion(date);
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
    final isModified = normalized != question.originalQuestionText;
    return _database.saveDailyQuestion(
      question.copyWith(
        questionText: normalized,
        isModified: isModified,
        updatedAt: DateTime.now(),
      ),
    );
  }

  Future<DailyQuestion> restoreDefaultQuestion(DateTime date) async {
    final existing = await _database.getDailyQuestionByDate(date);
    final resolved = await resolveQuestion(date);
    final question =
        existing ?? await ensureQuestion(date, definition: resolved);
    final text = question.originalQuestionText;
    return _database.saveDailyQuestion(
      question.copyWith(
        questionText: text,
        isModified: false,
        updatedAt: DateTime.now(),
      ),
    );
  }
}
