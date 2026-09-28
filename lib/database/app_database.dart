import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/focus_session.dart';
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
      version: 4,
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
            plan_date INTEGER NOT NULL
          )
        ''');

        await _insertInitialTasks(db);
        await _createFocusSessionTable(db);
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
            final createdAt =
                DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int);
            final planDate =
                DateTime(createdAt.year, createdAt.month, createdAt.day)
                    .millisecondsSinceEpoch;
            await db.update(
              'task',
              {'plan_date': planDate},
              where: 'id = ?',
              whereArgs: [row['id']],
            );
          }
        }
      },
    );
    return _database!;
  }

  Future<List<Task>> loadTasks() async {
    final db = await database;
    final rows = await db.query(
      'task',
      orderBy: 'completed ASC, created_at DESC',
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
        'completed_at':
            initialTask['completed'] == 1 ? createdAt - index : null,
      });
    }
  }
}
