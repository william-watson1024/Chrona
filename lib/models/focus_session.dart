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
    return FocusSession(
      id: map['id'] as int?,
      taskId: map['task_id'] as int?,
      taskTitleSnapshot: map['task_title_snapshot'] as String,
      startedAt: DateTime.fromMillisecondsSinceEpoch(map['started_at'] as int),
      endedAt: DateTime.fromMillisecondsSinceEpoch(map['ended_at'] as int),
      plannedDurationSeconds: map['planned_duration_seconds'] as int,
      actualDurationSeconds: map['actual_duration_seconds'] as int,
      note: map['note'] as String?,
      status:
          FocusSessionStatusValue.fromDatabaseValue(map['status'] as String),
      createdAt: DateTime.fromMillisecondsSinceEpoch(map['created_at'] as int),
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
}
