class Task {
  const Task({
    this.id,
    required this.title,
    this.note,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    this.durationSeconds = 25 * 60,
  });

  final int? id;
  final String title;
  final String? note;
  final bool completed;
  final int createdAt;
  final int? completedAt;
  final int durationSeconds;

  factory Task.fromMap(Map<String, Object?> map) {
    return Task(
      id: map['id'] as int?,
      title: map['title'] as String,
      note: map['note'] as String?,
      completed: (map['completed'] as int) == 1,
      createdAt: map['created_at'] as int,
      completedAt: map['completed_at'] as int?,
      durationSeconds: map['duration_seconds'] as int? ?? 25 * 60,
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
    );
  }
}
