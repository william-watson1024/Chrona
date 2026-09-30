import 'dart:convert';

import 'package:flutter/services.dart';

import '../models/daily_question.dart';

class QuestionRepository {
  QuestionRepository({Future<String> Function(String asset)? assetLoader})
      : _assetLoader = assetLoader ?? rootBundle.loadString;

  static final shared = QuestionRepository();

  static const dailyAsset = 'assets/question/拾年每日一问.json';
  static const specialAsset = 'assets/question/特殊日期每日一问.json';
  static const randomAsset = 'assets/question/拾年随机问题池_4000.json';

  final Future<String> Function(String asset) _assetLoader;
  Map<String, dynamic>? _daily;
  Map<String, dynamic>? _special;
  Future<void>? _loading;
  List<RandomQuestionDefinition>? _randomQuestions;
  Future<void>? _randomLoading;

  Future<QuestionDefinition?> dailyQuestion(DateTime date) async {
    await _load();
    final monthDay = '${date.month}.${date.day}';
    final record = _daily?[monthDay];
    if (record is! Map) return null;
    final text = record[date.year.toString()];
    if (text is! String || text.trim().isEmpty) return null;
    return QuestionDefinition(
      questionText: text.trim(),
      sourceType: 'DAILY',
      sourceKey: monthDay,
    );
  }

  Future<QuestionDefinition?> specialQuestion(
    DateTime date, {
    DateTime? birthday,
  }) async {
    await _load();
    final specialDays = _special?['special_days'];
    if (specialDays is! Map) return null;

    final matches = <_SpecialMatch>[];
    for (final entry in specialDays.entries) {
      if (entry.value is! Map) continue;
      final definition = Map<String, dynamic>.from(entry.value as Map);
      final priority = _asInt(definition['priority']) ?? 0;
      if (!_matches(definition, date, birthday: birthday)) continue;
      final questions = definition['questions'];
      final text = questions is Map ? questions[date.year.toString()] : null;
      if (text is! String || text.trim().isEmpty) continue;
      matches.add(_SpecialMatch(
        key: entry.key.toString(),
        priority: priority,
        definition: QuestionDefinition(
          questionText: text.trim(),
          sourceType:
              entry.key.toString() == 'birthday' ? 'BIRTHDAY' : 'SPECIAL',
          sourceKey: entry.key.toString(),
        ),
      ));
    }

    if (matches.isEmpty) return null;
    matches.sort((a, b) {
      final priority = b.priority.compareTo(a.priority);
      return priority != 0 ? priority : a.key.compareTo(b.key);
    });
    return matches.first.definition;
  }

  Future<List<RandomQuestionDefinition>> randomQuestions() async {
    await _loadRandomQuestions();
    return _randomQuestions!;
  }

  Future<void> _load() async {
    if (_daily != null && _special != null) return;
    final loading = _loading;
    if (loading != null) return loading;

    final future = _loadAssets();
    _loading = future;
    try {
      await future;
    } finally {
      if (identical(_loading, future)) _loading = null;
    }
  }

  Future<void> _loadAssets() async {
    final dailyJson = await _assetLoader(dailyAsset);
    final specialJson = await _assetLoader(specialAsset);
    final daily = jsonDecode(dailyJson);
    final special = jsonDecode(specialJson);
    if (daily is! Map || special is! Map) {
      throw const FormatException('Invalid CHRONA question assets');
    }
    _daily = Map<String, dynamic>.from(daily);
    _special = Map<String, dynamic>.from(special);
  }

  Future<void> _loadRandomQuestions() async {
    if (_randomQuestions != null) return;
    final loading = _randomLoading;
    if (loading != null) return loading;

    final future = _loadRandomAsset();
    _randomLoading = future;
    try {
      await future;
    } finally {
      if (identical(_randomLoading, future)) _randomLoading = null;
    }
  }

  Future<void> _loadRandomAsset() async {
    final decoded = jsonDecode(await _assetLoader(randomAsset));
    if (decoded is! Map || decoded['questions'] is! List) {
      throw const FormatException('Invalid CHRONA random question asset');
    }

    final ids = <String>{};
    final questions = <RandomQuestionDefinition>[];
    for (final item in decoded['questions'] as List) {
      if (item is! Map) continue;
      final definition = Map<String, dynamic>.from(item);
      final id = definition['id']?.toString().trim() ?? '';
      final theme = definition['theme']?.toString().trim() ?? '';
      final question = definition['question']?.toString().trim() ?? '';
      if (id.isEmpty || question.isEmpty || !ids.add(id)) continue;
      questions.add(RandomQuestionDefinition(
        id: id,
        theme: theme,
        questionText: question,
      ));
    }
    if (questions.isEmpty) {
      throw const FormatException('Random question asset is empty');
    }
    _randomQuestions = List.unmodifiable(questions);
  }

  bool _matches(
    Map<String, dynamic> definition,
    DateTime date, {
    DateTime? birthday,
  }) {
    final calendar = definition['calendar'];
    final rule = definition['rule'];
    if (rule is! Map) return false;
    final ruleMap = Map<String, dynamic>.from(rule);

    switch (calendar) {
      case 'gregorian':
        return date.month == _asInt(ruleMap['month']) &&
            date.day == _asInt(ruleMap['day']);
      case 'weekday_rule':
        final month = _asInt(ruleMap['month']);
        final ordinal = _asInt(ruleMap['ordinal']);
        final weekday = _weekday(ruleMap['weekday']);
        if (month == null ||
            ordinal == null ||
            weekday == null ||
            date.month != month ||
            date.weekday != weekday) {
          return false;
        }
        return ((date.day - 1) ~/ 7) + 1 == ordinal;
      case 'lunar':
        final lunarMonth = _asInt(ruleMap['month']);
        final lunarDay = _asInt(ruleMap['day']);
        return lunarMonth != null &&
            lunarDay != null &&
            _lunarDate(date) == '$lunarMonth-$lunarDay';
      case 'relative_lunar':
        if (ruleMap['relative_to'] != 'spring_festival') return false;
        final offset = _asInt(ruleMap['offset_days']) ?? 0;
        final springFestival = _springFestival(date.year);
        return springFestival != null &&
            _sameDay(date, springFestival.add(Duration(days: offset)));
      case 'solar_term':
        return ruleMap['name'] == 'qingming' &&
            _sameDay(date, _qingming(date.year));
      case 'custom':
        return birthday != null &&
            date.month == birthday.month &&
            date.day == birthday.day;
      default:
        return false;
    }
  }

  static int? _asInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '');
  }

  static int? _weekday(Object? value) {
    switch (value?.toString().toLowerCase()) {
      case 'monday':
        return DateTime.monday;
      case 'tuesday':
        return DateTime.tuesday;
      case 'wednesday':
        return DateTime.wednesday;
      case 'thursday':
        return DateTime.thursday;
      case 'friday':
        return DateTime.friday;
      case 'saturday':
        return DateTime.saturday;
      case 'sunday':
        return DateTime.sunday;
      default:
        return null;
    }
  }

  static bool _sameDay(DateTime? left, DateTime? right) =>
      left != null &&
      right != null &&
      left.year == right.year &&
      left.month == right.month &&
      left.day == right.day;

  static DateTime? _springFestival(int year) => _lunarDates[year]?['1-1'];

  static String? _lunarDate(DateTime date) {
    final dates = _lunarDates[date.year];
    if (dates == null) return null;
    for (final entry in dates.entries) {
      if (_sameDay(date, entry.value)) return entry.key;
    }
    return null;
  }

  static DateTime? _qingming(int year) => _qingmingDates[year];

  static final _qingmingDates = <int, DateTime>{
    2026: DateTime(2026, 4, 5),
    2027: DateTime(2027, 4, 5),
    2028: DateTime(2028, 4, 4),
    2029: DateTime(2029, 4, 4),
    2030: DateTime(2030, 4, 5),
    2031: DateTime(2031, 4, 5),
    2032: DateTime(2032, 4, 4),
    2033: DateTime(2033, 4, 5),
    2034: DateTime(2034, 4, 4),
    2035: DateTime(2035, 4, 5),
    2036: DateTime(2036, 4, 4),
  };

  // The question asset explicitly covers 2026–2036. Keeping this small,
  // reviewable table avoids adding a heavyweight lunar-calendar dependency.
  static final _lunarDates = <int, Map<String, DateTime>>{
    2026: _year(2026, '02-17', '03-03', '06-19', '08-19', '09-25', '10-18'),
    2027: _year(2027, '02-06', '02-20', '06-09', '08-08', '09-15', '10-08'),
    2028: _year(2028, '01-26', '02-09', '05-28', '08-26', '10-03', '10-26'),
    2029: _year(2029, '02-13', '02-27', '06-16', '08-16', '09-22', '10-16'),
    2030: _year(2030, '02-03', '02-17', '06-05', '08-05', '09-12', '10-05'),
    2031: _year(2031, '01-23', '02-06', '06-24', '08-24', '10-01', '10-24'),
    2032: _year(2032, '02-11', '02-25', '06-12', '08-12', '09-19', '10-12'),
    2033: _year(2033, '01-31', '02-14', '06-01', '08-01', '09-08', '10-01'),
    2034: _year(2034, '02-19', '03-05', '06-20', '08-20', '09-27', '10-20'),
    2035: _year(2035, '02-08', '02-22', '06-10', '08-10', '09-16', '10-09'),
    2036: _year(2036, '01-28', '02-11', '05-30', '08-28', '10-04', '10-27'),
  };

  static Map<String, DateTime> _year(
    int year,
    String springFestival,
    String lantern,
    String dragonBoat,
    String qixi,
    String midAutumn,
    String doubleNinth,
  ) {
    DateTime date(String value) {
      final parts = value.split('-');
      return DateTime(year, int.parse(parts[0]), int.parse(parts[1]));
    }

    final spring = date(springFestival);
    return {
      '1-1': spring,
      '1-15': date(lantern),
      '5-5': date(dragonBoat),
      '7-7': date(qixi),
      '8-15': date(midAutumn),
      '9-9': date(doubleNinth),
    };
  }
}

class _SpecialMatch {
  const _SpecialMatch({
    required this.key,
    required this.priority,
    required this.definition,
  });

  final String key;
  final int priority;
  final QuestionDefinition definition;
}
