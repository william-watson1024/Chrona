# `task` 任务表

存储用户创建的任务，以及任务的完成状态、计划日期和当天排序。

## 字段字典

| 字段 | 类型 | 可空 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `id` | `INTEGER` | 否 | 自增 | 主键 |
| `title` | `TEXT` | 否 | — | 任务标题 |
| `note` | `TEXT` | 是 | `NULL` | 任务备注 |
| `completed` | `INTEGER` | 否 | `0` | 完成标记，`0/1` |
| `created_at` | `INTEGER` | 否 | — | 创建时间，Unix epoch 毫秒 |
| `completed_at` | `INTEGER` | 是 | `NULL` | 完成时间，Unix epoch 毫秒 |
| `duration_seconds` | `INTEGER` | 否 | `900` | 计划专注时长，单位秒 |
| `plan_date` | `INTEGER` | 否 | — | 任务计划日期当天零点，Unix epoch 毫秒 |
| `sort_order` | `INTEGER` | 否 | `0` | 同一计划日期内的显示顺序 |

## 使用规则

- 查询任务默认按 `plan_date ASC, sort_order ASC, created_at DESC` 排序。
- `plan_date` 在模型层会归一化为本地日期的当天零点。
- `completed` 在 Dart 模型中映射为 `bool`，写入 SQLite 时转换为 `0/1`。
- `focus_session.task_id` 可以指向此表的 `id`，但当前没有数据库级外键约束。
