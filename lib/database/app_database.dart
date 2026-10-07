import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/daily_question.dart';
import '../models/focus_session.dart';
import '../models/journal_entry.dart';
import '../models/task.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;
  Future<Database>? _openingDatabase;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final opening = _openingDatabase;
    if (opening != null) return opening;

    final future = _openDatabase();
    _openingDatabase = future;
    try {
      return await future;
    } finally {
      if (identical(_openingDatabase, future)) _openingDatabase = null;
    }
  }

  Future<Database> _openDatabase() async {
    final databaseDirectory = await getDatabasesPath();
    final databasePath = join(databaseDirectory, 'chrona.db');
    final database = await openDatabase(
      databasePath,
      version: 9,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE task (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            title TEXT NOT NULL,
            note TEXT,
            completed INTEGER NOT NULL DEFAULT 0,
            created_at INTEGER NOT NULL,
            completed_at INTEGER,
            duration_seconds INTEGER NOT NULL DEFAULT 900,
            plan_date INTEGER NOT NULL,
            sort_order INTEGER NOT NULL DEFAULT 0
          )
        ''');

        await _createFocusSessionTable(db);
        await _createJournalEntryTable(db);
        await _createDailyQuestionTable(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) {
          await db.execute(
            'ALTER TABLE task ADD COLUMN duration_seconds INTEGER NOT NULL DEFAULT 900',
          );
        }
        if (oldVersion < 3) {
          await _createFocusSessionTable(db);
        }
        if (oldVersion < 4) {
          await db.execute('ALTER TABLE task ADD COLUMN plan_date INTEGER');
          final rows = await db.query(
            'task',
            columns: ['id', 'created_at'],
          );
          for (final row in rows) {
            final createdAtMilliseconds = _readInt(row['created_at']) ??
                DateTime.now().millisecondsSinceEpoch;
            final createdAt =
                DateTime.fromMillisecondsSinceEpoch(createdAtMilliseconds);
            final planDate =
                DateTime(createdAt.year, createdAt.month, createdAt.day)
                    .millisecondsSinceEpoch;
            await db.update(
              'task',
              {
                'created_at': createdAtMilliseconds,
                'plan_date': planDate,
              },
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
        if (oldVersion < 5) {
          await db.execute(
            'ALTER TABLE task ADD COLUMN sort_order INTEGER NOT NULL DEFAULT 0',
          );
          final rows = await db.query(
            'task',
            columns: ['id', 'plan_date', 'created_at'],
            orderBy: 'plan_date ASC, completed ASC, created_at DESC',
          );
          final nextOrderByDate = <int, int>{};
          for (final row in rows) {
            final planDate = _readInt(row['plan_date']) ??
                _readInt(row['created_at']) ??
                DateTime.now().millisecondsSinceEpoch;
            final nextOrder = nextOrderByDate[planDate] ?? 0;
            await db.update(
              'task',
              {'sort_order': nextOrder},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
            nextOrderByDate[planDate] = nextOrder + 1;
          }
        }
        if (oldVersion < 6) {
          await _repairNullValues(db);
        }
        if (oldVersion < 7) {
          await _createJournalEntryTable(db);
        }
        if (oldVersion < 8) {
          await _migrateDailyQuestions(db);
        }
        if (oldVersion < 9) {
          await _removeSeedTasks(db);
        }
      },
    );
    _database = database;
    return database;
  }

  Future<List<Task>> loadTasks() async {
    final db = await database;
    final rows = await db.query(
      'task',
      orderBy: 'plan_date ASC, sort_order ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
  }

  Future<Map<String, dynamic>> exportData() async {
    final db = await database;
    await _createJournalEntryTable(db);
    await _createDailyQuestionTable(db);
    final tasks = await db.query('task', orderBy: 'id ASC');
    final sessions = await db.query('focus_session', orderBy: 'id ASC');
    final dailyQuestions = await db.query('daily_question', orderBy: 'id ASC');
    final journals = await db.query('journal_entry', orderBy: 'id ASC');

    return {
      'format': 'chrona_backup',
      'version': 1,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'tasks': tasks.map((row) => Map<String, dynamic>.from(row)).toList(),
      'focus_sessions':
          sessions.map((row) => Map<String, dynamic>.from(row)).toList(),
      'daily_questions':
          dailyQuestions.map((row) => Map<String, dynamic>.from(row)).toList(),
      'journal_entries':
          journals.map((row) => Map<String, dynamic>.from(row)).toList(),
    };
  }

  Future<void> importData(Map<String, dynamic> payload) async {
    if (payload['format'] != 'chrona_backup' || payload['version'] != 1) {
      throw const FormatException('Invalid CHRONA backup file');
    }

    final tasks = _backupRows(payload['tasks'], 'tasks');
    final sessions = _backupRows(payload['focus_sessions'], 'focus_sessions');
    final dailyQuestions = _backupRows(
      payload['daily_questions'] ?? const [],
      'daily_questions',
    );
    final journals = _backupRows(payload['journal_entries'], 'journal_entries');
    final db = await database;
    await _createJournalEntryTable(db);
    await _createDailyQuestionTable(db);

    await db.transaction((txn) async {
      await txn.delete('journal_entry');
      await txn.delete('daily_question');
      await txn.delete('focus_session');
      await txn.delete('task');

      for (final row in tasks) {
        await txn.insert('task', _taskBackupValues(row));
      }
      for (final row in sessions) {
        await txn.insert('focus_session', _focusSessionBackupValues(row));
      }
      final questionIdsByDate = <String, int>{};
      for (final row in dailyQuestions) {
        final values = _dailyQuestionBackupValues(row);
        final id = await txn.insert('daily_question', values);
        questionIdsByDate[values['entry_date']! as String] = id;
      }
      for (final row in journals) {
        final values = _journalBackupValues(row);
        var questionId = _readInt(values['question_id']);
        final entryDate = values['entry_date']! as String;
        if (questionId == null ||
            !questionIdsByDate.values.contains(questionId)) {
          final legacyText = values['question_text'] as String?;
          if (legacyText != null && legacyText.trim().isNotEmpty) {
            questionId = questionIdsByDate[entryDate];
            if (questionId == null) {
              final now = _readInt(values['updated_at']) ??
                  _readInt(values['created_at']) ??
                  DateTime.now().millisecondsSinceEpoch;
              questionId = await txn.insert('daily_question', {
                'entry_date': entryDate,
                'source_type': 'CUSTOM',
                'source_key': 'legacy',
                'original_question_text': legacyText,
                'question_text': legacyText,
                'is_modified': 0,
                'created_at': _readInt(values['created_at']) ?? now,
                'updated_at': now,
              });
              questionIdsByDate[entryDate] = questionId;
            }
          }
        }
        values['question_id'] = questionId;
        await txn.insert('journal_entry', values);
      }
    });
  }

  Future<Task> insertTask(Task task) async {
    final db = await database;
    final id = await db.insert('task', task.toMap()..remove('id'));
    return task.copyWith(id: id);
  }

  Future<void> updateTask(Task task) async {
    final id = task.id;
    if (id == null) return;

    final db = await database;
    await db.update('task', task.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [id]);
  }

  Future<void> updateTaskOrders(Iterable<Task> tasks) async {
    final db = await database;
    final batch = db.batch();
    for (final task in tasks) {
      final id = task.id;
      if (id == null) continue;
      batch.update(
        'task',
        {'sort_order': task.sortOrder},
        where: 'id = ?',
        whereArgs: [id],
      );
    }
    await batch.commit(noResult: true);
  }

  Future<void> deleteTask(Task task) async {
    final id = task.id;
    if (id == null) return;

    final db = await database;
    await db.delete('task', where: 'id = ?', whereArgs: [id]);
  }

  Future<List<FocusSession>> loadFocusSessions() async {
    final db = await database;
    final rows = await db.query(
      'focus_session',
      orderBy: 'started_at DESC, id DESC',
    );
    return rows.map(FocusSession.fromMap).toList();
  }

  Future<FocusSession?> findFocusSession({
    required int? taskId,
    required DateTime startedAt,
    required DateTime endedAt,
    required String status,
  }) async {
    final db = await database;
    final taskClause = taskId == null ? 'task_id IS NULL' : 'task_id = ?';
    final whereArgs = <Object?>[
      if (taskId != null) taskId,
      startedAt.millisecondsSinceEpoch,
      endedAt.millisecondsSinceEpoch,
      status,
    ];
    final rows = await db.query(
      'focus_session',
      where: '$taskClause AND started_at = ? AND ended_at = ? AND status = ?',
      whereArgs: whereArgs,
      limit: 1,
    );
    return rows.isEmpty ? null : FocusSession.fromMap(rows.first);
  }

  Future<FocusSession> insertFocusSession(FocusSession session) async {
    final db = await database;
    final id = await db.insert('focus_session', session.toMap()..remove('id'));
    return session.copyWith(id: id);
  }

  Future<void> updateFocusSessionNote(int id, String? note) async {
    final db = await database;
    await db.update(
      'focus_session',
      {'note': note},
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<void> updateFocusSessionDetails(
    int id, {
    required String taskTitleSnapshot,
    required String? note,
  }) async {
    final db = await database;
    await db.update(
      'focus_session',
      {
        'task_title_snapshot': taskTitleSnapshot,
        'note': note,
      },
      where: 'id = ?',
      whereArgs: [id],
    );
  }

  Future<JournalEntry?> getJournalByDate(DateTime date) async {
    final db = await database;
    await _createJournalEntryTable(db);
    final rows = await db.query(
      'journal_entry',
      where: 'entry_date = ?',
      whereArgs: [JournalEntry.dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return JournalEntry.fromMap(rows.first);
  }

  Future<List<JournalEntry>> getJournals() async {
    final db = await database;
    await _createJournalEntryTable(db);
    final rows = await db.query(
      'journal_entry',
      orderBy: 'entry_date DESC, id DESC',
    );
    return rows.map(JournalEntry.fromMap).toList(growable: false);
  }

  Future<DailyQuestion?> getDailyQuestionByDate(DateTime date) async {
    final db = await database;
    await _createDailyQuestionTable(db);
    final rows = await db.query(
      'daily_question',
      where: 'entry_date = ?',
      whereArgs: [JournalEntry.dateKey(date)],
      limit: 1,
    );
    if (rows.isEmpty) return null;
    return DailyQuestion.fromMap(rows.first);
  }

  Future<List<DailyQuestion>> getDailyQuestions() async {
    final db = await database;
    await _createDailyQuestionTable(db);
    final rows = await db.query(
      'daily_question',
      orderBy: 'entry_date ASC, id ASC',
    );
    return rows.map(DailyQuestion.fromMap).toList(growable: false);
  }

  Future<DailyQuestion> saveDailyQuestion(DailyQuestion question) async {
    final db = await database;
    await _createDailyQuestionTable(db);
    final existingRows = await db.query(
      'daily_question',
      where: 'entry_date = ?',
      whereArgs: [question.entryDate],
      limit: 1,
    );
    if (existingRows.isEmpty) {
      final id = await db.insert(
        'daily_question',
        question.toMap()..remove('id'),
      );
      return question.copyWith(id: id);
    }
    final existing = DailyQuestion.fromMap(existingRows.first);
    await db.update(
      'daily_question',
      question.toMap()..remove('id'),
      where: 'id = ?',
      whereArgs: [existing.id],
    );
    return question.copyWith(id: existing.id);
  }

  Future<JournalEntry> saveJournal(JournalEntry entry) async {
    final db = await database;
    await _createJournalEntryTable(db);
    final existingRows = await db.query(
      'journal_entry',
      columns: ['id'],
      where: 'entry_date = ?',
      whereArgs: [entry.entryDate],
      limit: 1,
    );

    if (existingRows.isEmpty) {
      final id = await db.insert('journal_entry', entry.toMap()..remove('id'));
      return entry.copyWith(id: id);
    }

    final existingId = _readInt(existingRows.first['id']);
    await db.update(
      'journal_entry',
      entry.toMap()..remove('id'),
      where: 'entry_date = ?',
      whereArgs: [entry.entryDate],
    );
    return entry.copyWith(id: existingId);
  }

  Future<void> updateJournal(JournalEntry entry) async {
    final db = await database;
    await _createJournalEntryTable(db);
    final values = entry.toMap()..remove('id');
    if (entry.id != null) {
      await db.update(
        'journal_entry',
        values,
        where: 'id = ?',
        whereArgs: [entry.id],
      );
      return;
    }
    await db.update(
      'journal_entry',
      values,
      where: 'entry_date = ?',
      whereArgs: [entry.entryDate],
    );
  }

  Future<void> _createFocusSessionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS focus_session (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        task_id INTEGER,
        task_title_snapshot TEXT NOT NULL,
        started_at INTEGER NOT NULL,
        ended_at INTEGER NOT NULL,
        planned_duration_seconds INTEGER NOT NULL,
        actual_duration_seconds INTEGER NOT NULL,
        note TEXT,
        status TEXT NOT NULL,
        created_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createJournalEntryTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS journal_entry (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL UNIQUE,
        question_id INTEGER,
        question_text TEXT,
        question_answer TEXT,
        content TEXT,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _createDailyQuestionTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS daily_question (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        entry_date TEXT NOT NULL UNIQUE,
        source_type TEXT NOT NULL,
        source_key TEXT,
        original_question_text TEXT NOT NULL,
        question_text TEXT NOT NULL,
        is_modified INTEGER NOT NULL DEFAULT 0,
        created_at INTEGER NOT NULL,
        updated_at INTEGER NOT NULL
      )
    ''');
  }

  Future<void> _migrateDailyQuestions(Database db) async {
    await _createDailyQuestionTable(db);
    final rows = await db.query(
      'journal_entry',
      columns: [
        'id',
        'entry_date',
        'question_text',
        'created_at',
        'updated_at',
      ],
    );
    for (final row in rows) {
      final text = row['question_text'] as String?;
      final entryDate = row['entry_date'] as String?;
      if (entryDate == null || text == null || text.trim().isEmpty) continue;
      final existing = await db.query(
        'daily_question',
        columns: ['id'],
        where: 'entry_date = ?',
        whereArgs: [entryDate],
        limit: 1,
      );
      final questionId = existing.isNotEmpty
          ? _readInt(existing.first['id'])
          : await db.insert('daily_question', {
              'entry_date': entryDate,
              'source_type': 'CUSTOM',
              'source_key': 'legacy',
              'original_question_text': text,
              'question_text': text,
              'is_modified': 0,
              'created_at': _readInt(row['created_at']) ??
                  DateTime.now().millisecondsSinceEpoch,
              'updated_at': _readInt(row['updated_at']) ??
                  DateTime.now().millisecondsSinceEpoch,
            });
      if (questionId != null) {
        await db.update(
          'journal_entry',
          {'question_id': questionId},
          where: 'id = ?',
          whereArgs: [row['id']],
        );
      }
    }
  }

  Future<void> _repairNullValues(Database db) async {
    final taskRows = await db.query(
      'task',
      columns: [
        'id',
        'title',
        'completed',
        'created_at',
        'duration_seconds',
        'plan_date',
        'sort_order',
      ],
    );
    final now = DateTime.now().millisecondsSinceEpoch;
    for (final row in taskRows) {
      final id = _readInt(row['id']);
      if (id == null) continue;

      final createdAt = _readInt(row['created_at']) ?? now;
      final createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
      final planDate = _readInt(row['plan_date']) ??
          DateTime(createdDate.year, createdDate.month, createdDate.day)
              .millisecondsSinceEpoch;
      final duration = _readInt(row['duration_seconds']) ?? 25 * 60;
      final completed = _readInt(row['completed']) ?? 0;
      final sortOrder = _readInt(row['sort_order']) ?? 0;

      await db.update(
        'task',
        {
          'completed': completed == 1 ? 1 : 0,
          'created_at': createdAt,
          'duration_seconds': duration,
          'plan_date': planDate,
          'sort_order': sortOrder,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }

    final sessionRows = await db.query(
      'focus_session',
      columns: [
        'id',
        'task_title_snapshot',
        'started_at',
        'ended_at',
        'planned_duration_seconds',
        'actual_duration_seconds',
        'status',
        'created_at',
      ],
    );
    for (final row in sessionRows) {
      final id = _readInt(row['id']);
      if (id == null) continue;

      final startedAt = _readInt(row['started_at']) ?? now;
      final endedAt = _readInt(row['ended_at']) ?? startedAt;
      final actual = _readInt(row['actual_duration_seconds']) ??
          ((endedAt - startedAt) ~/ 1000).clamp(0, 1 << 31).toInt();
      await db.update(
        'focus_session',
        {
          'task_title_snapshot':
              row['task_title_snapshot'] as String? ?? '未命名任务',
          'started_at': startedAt,
          'ended_at': endedAt,
          'planned_duration_seconds':
              _readInt(row['planned_duration_seconds']) ?? actual,
          'actual_duration_seconds': actual,
          'status': row['status'] as String? ?? 'COMPLETED',
          'created_at': _readInt(row['created_at']) ?? endedAt,
        },
        where: 'id = ?',
        whereArgs: [id],
      );
    }
  }

  Future<void> _removeSeedTasks(Database db) async {
    const seedTasks = <(String, String)>[
      ('阅读 Orca 论文', '继续看 Section 3'),
      ('写 RagForge', '实现文档解析接口'),
      ('上课作业', '完成第二题'),
      ('健身', '胸 + 肩'),
      ('整理笔记', 'SGLang 阅读笔记'),
      ('看技术分享', 'AI Infra 系列'),
    ];

    for (final (title, note) in seedTasks) {
      await db.delete(
        'task',
        where: 'title = ? AND note = ?',
        whereArgs: [title, note],
      );
    }
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}

List<Map<String, dynamic>> _backupRows(Object? value, String field) {
  if (value is! List) {
    throw FormatException('Backup field "$field" must be a list');
  }
  final rows = <Map<String, dynamic>>[];
  for (final row in value) {
    if (row is! Map) {
      throw FormatException('Backup field "$field" contains an invalid row');
    }
    rows.add(Map<String, dynamic>.from(row));
  }
  return List.unmodifiable(rows);
}

Map<String, Object?> _taskBackupValues(Map<String, dynamic> row) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final createdAt = _readInt(row['created_at']) ?? now;
  final createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
  final id = _readInt(row['id']);
  return {
    if (id != null) 'id': id,
    'title': row['title'] as String? ?? '\u9ED8\u8BA4\u4EFB\u52A1',
    'note': row['note'] as String?,
    'completed': _backupBool(row['completed']),
    'created_at': createdAt,
    'completed_at': _readInt(row['completed_at']),
    'duration_seconds': _readInt(row['duration_seconds']) ?? 25 * 60,
    'plan_date': _readInt(row['plan_date']) ??
        DateTime(createdDate.year, createdDate.month, createdDate.day)
            .millisecondsSinceEpoch,
    'sort_order': _readInt(row['sort_order']) ?? 0,
  };
}

Map<String, Object?> _focusSessionBackupValues(Map<String, dynamic> row) {
  final now = DateTime.now().millisecondsSinceEpoch;
  final startedAt = _readInt(row['started_at']) ?? now;
  final endedAt = _readInt(row['ended_at']) ?? startedAt;
  final id = _readInt(row['id']);
  final status = row['status'];
  if (status != null && status != 'COMPLETED' && status != 'CANCELLED') {
    throw const FormatException('Invalid focus session status');
  }
  return {
    if (id != null) 'id': id,
    'task_id': _readInt(row['task_id']),
    'task_title_snapshot':
        row['task_title_snapshot'] as String? ?? '\u9ED8\u8BA4\u4EFB\u52A1',
    'started_at': startedAt,
    'ended_at': endedAt,
    'planned_duration_seconds': _readInt(row['planned_duration_seconds']) ?? 0,
    'actual_duration_seconds': _readInt(row['actual_duration_seconds']) ??
        ((endedAt - startedAt) ~/ 1000).clamp(0, 1 << 31).toInt(),
    'note': row['note'] as String?,
    'status': status == 'CANCELLED' ? 'CANCELLED' : 'COMPLETED',
    'created_at': _readInt(row['created_at']) ?? endedAt,
  };
}

Map<String, Object?> _journalBackupValues(Map<String, dynamic> row) {
  final entryDate = row['entry_date'] as String?;
  if (entryDate == null || !_isValidDateKey(entryDate)) {
    throw const FormatException('Invalid journal entry date');
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = _readInt(row['id']);
  return {
    if (id != null) 'id': id,
    'entry_date': entryDate,
    'question_id': _readInt(row['question_id']),
    'question_text': row['question_text'] as String?,
    'question_answer': row['question_answer'] as String?,
    'content': row['content'] as String?,
    'created_at': _readInt(row['created_at']) ?? now,
    'updated_at': _readInt(row['updated_at']) ?? now,
  };
}

Map<String, Object?> _dailyQuestionBackupValues(Map<String, dynamic> row) {
  final entryDate = row['entry_date'] as String?;
  if (entryDate == null || !_isValidDateKey(entryDate)) {
    throw const FormatException('Invalid daily question date');
  }
  final original = row['original_question_text'] as String?;
  final question = row['question_text'] as String?;
  if (original == null ||
      original.trim().isEmpty ||
      question == null ||
      question.trim().isEmpty) {
    throw const FormatException('Invalid daily question text');
  }
  final now = DateTime.now().millisecondsSinceEpoch;
  final id = _readInt(row['id']);
  final sourceType = row['source_type'] as String? ?? 'CUSTOM';
  const sourceTypes = {'DAILY', 'SPECIAL', 'BIRTHDAY', 'CUSTOM'};
  if (!sourceTypes.contains(sourceType)) {
    throw const FormatException('Invalid daily question source type');
  }
  return {
    if (id != null) 'id': id,
    'entry_date': entryDate,
    'source_type': sourceType,
    'source_key': row['source_key'] as String?,
    'original_question_text': original,
    'question_text': question,
    'is_modified': _backupBool(row['is_modified']),
    'created_at': _readInt(row['created_at']) ?? now,
    'updated_at': _readInt(row['updated_at']) ?? now,
  };
}

bool _isValidDateKey(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return false;
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  final date = DateTime(year, month, day);
  return date.year == year && date.month == month && date.day == day;
}

int _backupBool(Object? value) {
  if (value is bool) return value ? 1 : 0;
  return _readInt(value) == 1 ? 1 : 0;
}
