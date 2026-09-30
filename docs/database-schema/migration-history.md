# 数据库迁移记录

以下记录根据 `lib/database/app_database.dart` 中的 `openDatabase(... version: 9 ...)` 和 `onUpgrade` 逻辑整理。

## 版本变化

| 版本 | 变化 | 数据处理 |
| --- | --- | --- |
| 1 | 建立 `task` 基础表 | 新安装时创建空任务表，不写入示例任务 |
| 2 | `task.duration_seconds` | 新增字段，默认值 `900` 秒 |
| 3 | 建立 `focus_session` | 创建专注记录表 |
| 4 | `task.plan_date` | 新增字段；根据 `created_at` 回填任务日期 |
| 5 | `task.sort_order` | 新增字段；按日期、完成状态、创建时间计算初始顺序 |
| 6 | 空值修复 | 修复任务和专注记录中关键字段的空值；不改变表结构 |
| 7 | 建立 `journal_entry` | 创建日记表 |
| 8 | 建立 `daily_question` | 创建按日期冻结的问题实例，并把已有非空 `journal_entry.question_text` 迁移为 `CUSTOM / legacy` 问题 |
| 9 | 移除示例任务 | 删除早期版本可能写入的固定示例任务；不影响用户创建的其他任务 |

## 迁移注意事项

- 新安装用户直接按当前版本创建完整结构。
- 从旧版本升级时，迁移按版本号顺序执行。
- `task.plan_date` 在 v4 中先以可空字段加入，再通过回填逻辑补齐；当前新建表结构中为 `NOT NULL`。
- `focus_session.task_id` 当前没有 `FOREIGN KEY` 约束，因此删除任务不会级联删除历史专注记录。
- v6 是数据修复迁移，不是 DDL 迁移；后续如果增加字段或约束，应继续提升数据库版本号并追加迁移分支。
- v8 不删除或清空数据库；迁移只为已有非空日记问题创建 `daily_question`，保留原 `created_at`、回答、正文，并回填 `journal_entry.question_id`。空问题不创建实例。
