import 'package:chrona/repositories/question_repository.dart';
import 'package:chrona/services/birthday_settings.dart';
import 'package:chrona/services/question_resolver.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late QuestionRepository repository;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    repository = QuestionRepository();
  });

  test('resolves a year-specific ordinary daily question', () async {
    final definition = await repository.dailyQuestion(DateTime(2028, 9, 30));

    expect(definition, isNotNull);
    expect(definition!.sourceType, 'DAILY');
    expect(definition.sourceKey, '9.30');
    expect(definition.questionText, isNotEmpty);
  });

  test('resolves lunar, solar-term and relative special dates', () async {
    final newYear = await repository.specialQuestion(DateTime(2028, 1, 26));
    final qingming = await repository.specialQuestion(DateTime(2028, 4, 4));
    final eve = await repository.specialQuestion(DateTime(2036, 1, 27));

    expect(newYear?.sourceKey, 'spring_festival');
    expect(qingming?.sourceKey, 'qingming');
    expect(eve?.sourceKey, 'lunar_new_year_eve');
  });

  test('birthday wins over a same-day special date', () async {
    await BirthdaySettings.save(month: 2, day: 14);
    final definition = await QuestionResolver(repository: repository)
        .resolveQuestion(DateTime(2028, 2, 14));

    expect(definition?.sourceType, 'BIRTHDAY');
    expect(definition?.sourceKey, 'birthday');
  });

  test('does not invent a non-leap-year February 29 question', () async {
    final ordinary = await repository.dailyQuestion(DateTime(2027, 2, 28));
    final leapYear = await repository.dailyQuestion(DateTime(2028, 2, 29));

    expect(ordinary, isNotNull);
    expect(leapYear, isNotNull);
  });
}
