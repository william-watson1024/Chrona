class JournalEntry {
  const JournalEntry({
    this.id,
    required this.entryDate,
    this.questionId,
    required this.questionText,
    required this.questionAnswer,
    required this.content,
    required this.createdAt,
    required this.updatedAt,
  });

  static const defaultQuestionText =
      '\u5982\u679c\u6ca1\u6709\u4eba\u77e5\u9053\u4f60\u7684\u9009\u62e9\uff0c\n'
      '\u4f60\u8fd8\u4f1a\u505a\u540c\u6837\u7684\u51b3\u5b9a\u5417\uff1f';

  final int? id;
  final String entryDate;
  final int? questionId;
  final String? questionText;
  final String? questionAnswer;
  final String? content;
  final DateTime createdAt;
  final DateTime updatedAt;

  static String dateKey(DateTime date) {
    final local = date.toLocal();
    final month = local.month.toString().padLeft(2, '0');
    final day = local.day.toString().padLeft(2, '0');
    return '${local.year.toString().padLeft(4, '0')}-$month-$day';
  }

  static String normalizeQuestionText(String? value) {
    var text = value?.trim() ?? '';
    if (text.isEmpty) return defaultQuestionText;

    if (text.startsWith('\u201c') && text.endsWith('\u201d')) {
      text = text.substring(1, text.length - 1).trim();
    } else if (text.startsWith('"') && text.endsWith('"')) {
      text = text.substring(1, text.length - 1).trim();
    }
    return text.isEmpty ? defaultQuestionText : text;
  }

  factory JournalEntry.fromMap(Map<String, Object?> map) {
    final now = DateTime.now();
    return JournalEntry(
      id: _readInt(map['id']),
      entryDate: map['entry_date'] as String? ?? dateKey(now),
      questionId: _readInt(map['question_id']),
      questionText: map['question_text'] as String?,
      questionAnswer: map['question_answer'] as String?,
      content: map['content'] as String?,
      createdAt: _readDateTime(map['created_at'], now),
      updatedAt: _readDateTime(map['updated_at'], now),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'entry_date': entryDate,
      'question_id': questionId,
      'question_text': questionText,
      'question_answer': questionAnswer,
      'content': content,
      'created_at': createdAt.millisecondsSinceEpoch,
      'updated_at': updatedAt.millisecondsSinceEpoch,
    };
  }

  JournalEntry copyWith({int? id}) {
    return JournalEntry(
      id: id ?? this.id,
      entryDate: entryDate,
      questionId: questionId,
      questionText: questionText,
      questionAnswer: questionAnswer,
      content: content,
      createdAt: createdAt,
      updatedAt: updatedAt,
    );
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

DateTime _readDateTime(Object? value, DateTime fallback) {
  final milliseconds = _readInt(value);
  return milliseconds == null
      ? fallback
      : DateTime.fromMillisecondsSinceEpoch(milliseconds);
}
