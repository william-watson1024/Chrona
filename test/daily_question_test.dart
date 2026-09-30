import 'dart:math';

import 'package:chrona/models/daily_question.dart';
import 'package:chrona/repositories/question_repository.dart';
import 'package:chrona/services/birthday_settings.dart';
import 'package:chrona/services/question_resolver.dart';
import 'package:chrona/services/question_service.dart';
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

  test('loads the random question pool with unique non-empty questions',
      () async {
    final questions = await repository.randomQuestions();
    expect(questions.length, greaterThan(0));
    expect(questions.map((question) => question.id).toSet().length,
        questions.length);
    expect(questions.every((question) => question.questionText.isNotEmpty),
        isTrue);
  });

  test('caches the random pool after the first load', () async {
    var loadCount = 0;
    final cachedRepository = QuestionRepository(
      assetLoader: (asset) async {
        expect(asset, QuestionRepository.randomAsset);
        loadCount++;
        return '{"questions":[{"id":"RTEST","theme":"测试","question":"缓存测试问题"}]}';
      },
    );

    await cachedRepository.randomQuestions();
    await cachedRepository.randomQuestions();

    expect(loadCount, 1);
  });

  test('random selection avoids the current and recent questions', () {
    final service = QuestionService(random: Random(7));
    final pool = [
      const RandomQuestionDefinition(
        id: 'R0001',
        theme: '测试',
        questionText: '随机问题 B',
      ),
      const RandomQuestionDefinition(
        id: 'R0002',
        theme: '测试',
        questionText: '随机问题 C',
      ),
      const RandomQuestionDefinition(
        id: 'R0003',
        theme: '测试',
        questionText: '随机问题 D',
      ),
    ];
    final first = service.selectRandomQuestion(
      pool: pool,
      currentQuestion: '当天默认问题 A',
    );
    final second = service.selectRandomQuestion(
      pool: pool,
      currentQuestion: first.questionText,
    );

    expect(first.questionText, isNot('当天默认问题 A'));
    expect(second.questionText, isNot(first.questionText));
  });
}
