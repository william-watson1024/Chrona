class Task {
  const Task({
    this.id,
    required this.title,
    this.note,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    this.durationSeconds = 25 * 60,
    this.planDate,
  });

  final int? id;
  final String title;
  final String? note;
  final bool completed;
  final int createdAt;
  final int? completedAt;
  final int durationSeconds;
  final DateTime? planDate;

  DateTime get effectivePlanDate => startOfDay(
        planDate ?? DateTime.fromMillisecondsSinceEpoch(createdAt),
      );

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      note: map['note'] as String?,
      completed: (map['completed'] as int) == 1,
      createdAt: map['created_at'] as int,
      completedAt: map['completed_at'] as int?,
      durationSeconds: map['duration_seconds'] as int? ?? 25 * 60,
      planDate: map['plan_date'] == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(map['plan_date'] as int),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'title': title,
      'note': note,
      'completed': completed ? 1 : 0,
      'created_at': createdAt,
      'completed_at': completedAt,
      'duration_seconds': durationSeconds,
      'plan_date': effectivePlanDate.millisecondsSinceEpoch,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    String? note,
    bool? completed,
    int? createdAt,
    int? completedAt,
    int? durationSeconds,
    DateTime? planDate,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: note ?? this.note,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      planDate: planDate ?? this.planDate,
    );
  }
}

DateTime startOfDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}
