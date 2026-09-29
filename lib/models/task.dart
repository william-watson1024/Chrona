class Task {
  static const Object _copyWithUnset = Object();

  const Task({
    this.id,
    required this.title,
    this.note,
    required this.completed,
    required this.createdAt,
    this.completedAt,
    this.durationSeconds = 25 * 60,
    this.planDate,
    this.sortOrder = 0,
  });

  final int? id;
  final String title;
  final String? note;
  final bool completed;
  final int createdAt;
  final int? completedAt;
  final int durationSeconds;
  final DateTime? planDate;
  final int sortOrder;

  DateTime get effectivePlanDate => startOfDay(
        planDate ?? DateTime.fromMillisecondsSinceEpoch(createdAt),
      );

  factory Task.fromMap(Map<String, Object?> map) {
    final createdAt =
        _readInt(map['created_at']) ?? DateTime.now().millisecondsSinceEpoch;
    return Task(
      id: _readInt(map['id']),
      title: map['title'] as String? ?? '未命名任务',
      note: map['note'] as String?,
      completed: (_readInt(map['completed']) ?? 0) == 1,
      createdAt: createdAt,
      completedAt: _readInt(map['completed_at']),
      durationSeconds: _readInt(map['duration_seconds']) ?? 25 * 60,
      planDate: _readInt(map['plan_date']) == null
          ? null
          : DateTime.fromMillisecondsSinceEpoch(_readInt(map['plan_date'])!),
      sortOrder: _readInt(map['sort_order']) ?? 0,
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
      'sort_order': sortOrder,
    };
  }

  Task copyWith({
    int? id,
    String? title,
    Object? note = _copyWithUnset,
    bool? completed,
    int? createdAt,
    int? completedAt,
    int? durationSeconds,
    Object? planDate = _copyWithUnset,
    int? sortOrder,
    bool clearCompletedAt = false,
  }) {
    return Task(
      id: id ?? this.id,
      title: title ?? this.title,
      note: identical(note, _copyWithUnset) ? this.note : note as String?,
      completed: completed ?? this.completed,
      createdAt: createdAt ?? this.createdAt,
      completedAt: clearCompletedAt ? null : completedAt ?? this.completedAt,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      planDate: identical(planDate, _copyWithUnset)
          ? this.planDate
          : planDate as DateTime?,
      sortOrder: sortOrder ?? this.sortOrder,
    );
  }
}

DateTime startOfDay(DateTime date) {
  final local = date.toLocal();
  return DateTime(local.year, local.month, local.day);
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
