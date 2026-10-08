enum FocusSessionStatus { completed, cancelled }

extension FocusSessionStatusValue on FocusSessionStatus {
  String get databaseValue => switch (this) {
        FocusSessionStatus.completed => 'COMPLETED',
        FocusSessionStatus.cancelled => 'CANCELLED',
      };

  static FocusSessionStatus fromDatabaseValue(String value) {
    return value == 'CANCELLED'
        ? FocusSessionStatus.cancelled
        : FocusSessionStatus.completed;
  }
}

class FocusSession {
  const FocusSession({
    this.id,
    required this.taskId,
    required this.taskTitleSnapshot,
    required this.startedAt,
    required this.endedAt,
    required this.plannedDurationSeconds,
    required this.actualDurationSeconds,
    required this.note,
    required this.status,
    required this.createdAt,
  });

  final int? id;
  final int? taskId;
  final String taskTitleSnapshot;
  final DateTime startedAt;
  final DateTime endedAt;
  final int plannedDurationSeconds;
  final int actualDurationSeconds;
  final String? note;
  final FocusSessionStatus status;
  final DateTime createdAt;

  factory FocusSession.fromMap(Map<String, Object?> map) {
    final now = DateTime.now();
    final startedAt = _readDateTime(map['started_at'], now);
    final endedAt = _readDateTime(map['ended_at'], startedAt);
    return FocusSession(
      id: _readInt(map['id']),
      taskId: _readInt(map['task_id']),
      taskTitleSnapshot: map['task_title_snapshot'] as String? ?? '未命名任务',
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDurationSeconds: _readInt(map['planned_duration_seconds']) ?? 0,
      actualDurationSeconds: _readInt(map['actual_duration_seconds']) ??
          endedAt.difference(startedAt).inSeconds.clamp(0, 1 << 31).toInt(),
      note: map['note'] as String?,
      status: FocusSessionStatusValue.fromDatabaseValue(
        map['status'] as String? ?? 'COMPLETED',
      ),
      createdAt: _readDateTime(map['created_at'], endedAt),
    );
  }

  Map<String, Object?> toMap() {
    return {
      if (id != null) 'id': id,
      'task_id': taskId,
      'task_title_snapshot': taskTitleSnapshot,
      'started_at': startedAt.millisecondsSinceEpoch,
      'ended_at': endedAt.millisecondsSinceEpoch,
      'planned_duration_seconds': plannedDurationSeconds,
      'actual_duration_seconds': actualDurationSeconds,
      'note': note,
      'status': status.databaseValue,
      'created_at': createdAt.millisecondsSinceEpoch,
    };
  }

  FocusSession copyWith({int? id}) {
    return FocusSession(
      id: id ?? this.id,
      taskId: taskId,
      taskTitleSnapshot: taskTitleSnapshot,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDurationSeconds: plannedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      note: note,
      status: status,
      createdAt: createdAt,
    );
  }

  FocusSession copyWithNote(String? value) {
    return FocusSession(
      id: id,
      taskId: taskId,
      taskTitleSnapshot: taskTitleSnapshot,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDurationSeconds: plannedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      note: value,
      status: status,
      createdAt: createdAt,
    );
  }

  FocusSession copyWithTitleAndNote({
    required String title,
    required String? note,
  }) {
    return FocusSession(
      id: id,
      taskId: taskId,
      taskTitleSnapshot: title,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDurationSeconds: plannedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      note: note,
      status: status,
      createdAt: createdAt,
    );
  }

  FocusSession copyWithRoundDetails({
    required DateTime endedAt,
    required int plannedDurationSeconds,
    required int actualDurationSeconds,
    required FocusSessionStatus status,
  }) {
    return FocusSession(
      id: id,
      taskId: taskId,
      taskTitleSnapshot: taskTitleSnapshot,
      startedAt: startedAt,
      endedAt: endedAt,
      plannedDurationSeconds: plannedDurationSeconds,
      actualDurationSeconds: actualDurationSeconds,
      note: note,
      status: status,
      createdAt: createdAt,
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
