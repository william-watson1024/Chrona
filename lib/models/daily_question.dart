class DailyQuestion {
  const DailyQuestion({
    this.id,
    required this.entryDate,
    required this.sourceType,
    this.sourceKey,
    required this.originalQuestionText,
    required this.questionText,
    required this.isModified,
    required this.createdAt,
    required this.updatedAt,
  });

  final int? id;
  final String entryDate;
  final String sourceType;
  final String? sourceKey;
  final String originalQuestionText;
  final String questionText;
  final bool isModified;
  final DateTime createdAt;
  final DateTime updatedAt;

  factory DailyQuestion.fromMap(Map<String, Object?> map) {
    final now = DateTime.now();
    return DailyQuestion(
      id: _readInt(map['id']),
      entryDate: map['entry_date'] as String? ?? '',
      sourceType: map['source_type'] as String? ?? 'CUSTOM',
      sourceKey: map['source_key'] as String?,
      originalQuestionText: map['original_question_text'] as String? ?? '',
      questionText: map['question_text'] as String? ?? '',
      isModified: _readInt(map['is_modified']) == 1,
      createdAt: _readDateTime(map['created_at'], now),
      updatedAt: _readDateTime(map['updated_at'], now),
    );
  }

  Map<String, Object?> toMap() => {
        if (id != null) 'id': id,
        'entry_date': entryDate,
        'source_type': sourceType,
        'source_key': sourceKey,
        'original_question_text': originalQuestionText,
        'question_text': questionText,
        'is_modified': isModified ? 1 : 0,
        'created_at': createdAt.millisecondsSinceEpoch,
        'updated_at': updatedAt.millisecondsSinceEpoch,
      };

  DailyQuestion copyWith({
    int? id,
    String? sourceType,
    String? sourceKey,
    String? questionText,
    bool? isModified,
    DateTime? updatedAt,
  }) {
    return DailyQuestion(
      id: id ?? this.id,
      entryDate: entryDate,
      sourceType: sourceType ?? this.sourceType,
      sourceKey: sourceKey ?? this.sourceKey,
      originalQuestionText: originalQuestionText,
      questionText: questionText ?? this.questionText,
      isModified: isModified ?? this.isModified,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}

class QuestionDefinition {
  const QuestionDefinition({
    required this.questionText,
    required this.sourceType,
    this.sourceKey,
  });

  final String questionText;
  final String sourceType;
  final String? sourceKey;
}

class RandomQuestionDefinition {
  const RandomQuestionDefinition({
    required this.id,
    required this.theme,
    required this.questionText,
  });

  final String id;
  final String theme;
  final String questionText;
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
