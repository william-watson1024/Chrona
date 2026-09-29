# 数据库迁移记录

以下记录根据 `lib/database/app_database.dart` 中的 `openDatabase(... version: 7 ...)` 和 `onUpgrade` 逻辑整理。

## 版本变化

| 版本 | 变化 | 数据处理 |
| --- | --- | --- |
| 1 | 建立 `task` 基础表 | 新安装时创建任务表，并写入初始任务 |
| 2 | `task.duration_seconds` | 新增字段，默认值 `900` 秒 |
| 3 | 建立 `focus_session` | 创建专注记录表 |
| 4 | `task.plan_date` | 新增字段；根据 `created_at` 回填任务日期 |
| 5 | `task.sort_order` | 新增字段；按日期、完成状态、创建时间计算初始顺序 |
| 6 | 空值修复 | 修复任务和专注记录中关键字段的空值；不改变表结构 |
| 7 | 建立 `journal_entry` | 创建日记表 |

## 迁移注意事项

- 新安装用户直接按当前版本创建完整结构。
- 从旧版本升级时，迁移按版本号顺序执行。
- `task.plan_date` 在 v4 中先以可空字段加入，再通过回填逻辑补齐；当前新建表结构中为 `NOT NULL`。
- `focus_session.task_id` 当前没有 `FOREIGN KEY` 约束，因此删除任务不会级联删除历史专注记录。
- v6 是数据修复迁移，不是 DDL 迁移；后续如果增加字段或约束，应继续提升数据库版本号并追加迁移分支。
