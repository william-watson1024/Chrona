# CHRONA 数据库表结构

本文档整理当前应用实际使用的本地 SQLite 数据库结构。

## 基本信息

- 数据库文件：`chrona.db`
- 数据库类型：SQLite（通过 `sqflite` 使用）
- 当前应用数据库版本：7
- 运行时定义：[`lib/database/app_database.dart`](../../lib/database/app_database.dart)
- SQL 快照：[`schema.sql`](./schema.sql)

> `app_database.dart` 是运行时的唯一事实来源；本目录中的 SQL 和说明用于查阅、评审和后续维护。

## 表总览

| 表 | 用途 | 记录粒度 |
| --- | --- | --- |
| `task` | 任务及任务在某天的排序、完成状态 | 一条任务一行 |
| `focus_session` | 一次专注计时记录 | 一次专注一行 |
| `journal_entry` | 某天的日记内容和反思问题 | 每天最多一行 |

## 关系概览

```text
task 1 ─────────────── 0..N focus_session
  │                         │
  └─ focus_session.task_id  └─ 保存任务标题快照，避免任务标题变化影响历史展示

journal_entry
  └─ 通过 entry_date 保证每天最多一条，与 task / focus_session 没有数据库级关联
```

说明：当前实现没有声明 SQLite 外键约束。`focus_session.task_id` 是逻辑关联，可以为空；`task_title_snapshot` 用于保留专注发生时的任务标题。

## 存储约定

| 数据 | SQLite 存储方式 | 约定 |
| --- | --- | --- |
| 布尔值 | `INTEGER` | `0` 表示否，`1` 表示是；例如 `task.completed` |
| 时间点 | `INTEGER` | Unix epoch 毫秒；例如 `created_at`、`started_at` |
| 日期 | `TEXT` | `YYYY-MM-DD`；例如 `journal_entry.entry_date` |
| 时长 | `INTEGER` | 秒；例如 `duration_seconds` |
| 专注状态 | `TEXT` | `COMPLETED` 或 `CANCELLED` |

## 备份数据

`AppDatabase.exportData()` 导出以下三个集合：

- `tasks` → `task`
- `focus_sessions` → `focus_session`
- `journal_entries` → `journal_entry`

备份格式标识为 `chrona_backup`，当前备份版本为 `1`。导入时会在一个事务中清空并重建三张表中的数据。

## 文件索引

- [`schema.sql`](./schema.sql)：当前数据库结构的 SQL 快照
- [`migration-history.md`](./migration-history.md)：数据库版本 1～7 的迁移记录
- [`tables/task.md`](./tables/task.md)：任务表字段字典
- [`tables/focus_session.md`](./tables/focus_session.md)：专注记录表字段字典
- [`tables/journal_entry.md`](./tables/journal_entry.md)：日记表字段字典
