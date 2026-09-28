import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/focus_session.dart';
import '../models/journal_entry.dart';
import '../models/task.dart';

class AppDatabase {
  AppDatabase._();

  static final AppDatabase instance = AppDatabase._();

  Database? _database;

  Future<Database> get database async {
    final current = _database;
    if (current != null) return current;

    final databaseDirectory = await getDatabasesPath();
    final databasePath = join(databaseDirectory, 'chrona.db');
    _database = await openDatabase(
      databasePath,
      version: 7,
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

        await _insertInitialTasks(db);
        await _createFocusSessionTable(db);
        await _createJournalEntryTable(db);
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
            final createdAtMilliseconds =
                _readInt(row['created_at']) ?? DateTime.now().millisecondsSinceEpoch;
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
      },
    );
    return _database!;
  }

  Future<List<Task>> loadTasks() async {
    final db = await database;
    final rows = await db.query(
      'task',
      orderBy: 'plan_date ASC, sort_order ASC, created_at DESC',
    );
    return rows.map(Task.fromMap).toList();
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

  Future<void> _insertInitialTasks(Database db) async {
    final createdAt = DateTime.now().millisecondsSinceEpoch;
    final createdDate = DateTime.fromMillisecondsSinceEpoch(createdAt);
    final initialTasks = [
      {'title': '阅读 Orca 论文', 'note': '继续看 Section 3', 'completed': 0},
      {'title': '写 RagForge', 'note': '实现文档解析接口', 'completed': 0},
      {'title': '上课作业', 'note': '完成第二题', 'completed': 1},
      {'title': '健身', 'note': '胸 + 肩', 'completed': 0},
      {'title': '整理笔记', 'note': 'SGLang 阅读笔记', 'completed': 0},
      {'title': '看技术分享', 'note': 'AI Infra 系列', 'completed': 1},
    ];

    for (var index = 0; index < initialTasks.length; index++) {
      final initialTask = initialTasks[index];
      await db.insert('task', {
        ...initialTask,
        'created_at': createdAt - index,
        'duration_seconds': index.isEven ? 25 * 60 : 50 * 60,
        'plan_date':
            DateTime(createdDate.year, createdDate.month, createdDate.day)
                .millisecondsSinceEpoch,
        'sort_order': index,
        'completed_at':
            initialTask['completed'] == 1 ? createdAt - index : null,
      });
    }
  }
}

int? _readInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  if (value is String) return int.tryParse(value);
  return null;
}
