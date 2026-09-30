import '../database/app_database.dart';
import '../models/daily_question.dart';
import '../repositories/question_repository.dart';
import 'birthday_settings.dart';

class QuestionResolver {
  QuestionResolver({
    QuestionRepository? repository,
    AppDatabase? database,
  })  : _repository = repository ?? QuestionRepository.shared,
        _database = database;

  final QuestionRepository _repository;
  final AppDatabase? _database;

  Future<QuestionDefinition?> resolveQuestion(DateTime date) async {
    final saved = await _database?.getDailyQuestionByDate(date);
    if (saved != null) {
      return QuestionDefinition(
        questionText: saved.questionText,
        sourceType: saved.sourceType,
        sourceKey: saved.sourceKey,
      );
    }
    return resolveDefaultQuestion(date);
  }

  Future<QuestionDefinition?> resolveDefaultQuestion(DateTime date) async {
    final birthday = await BirthdaySettings.load();
    final birthdayOrSpecial = await _repository.specialQuestion(
      date,
      birthday: birthday,
    );
    if (birthdayOrSpecial?.sourceType == 'BIRTHDAY') {
      return birthdayOrSpecial;
    }
    return birthdayOrSpecial ?? _repository.dailyQuestion(date);
  }
}
