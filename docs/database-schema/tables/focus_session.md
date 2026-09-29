# `focus_session` 专注记录表

存储一次专注计时的完整记录，包括任务标题快照、计划时长、实际时长和结束状态。

## 字段字典

| 字段 | 类型 | 可空 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `id` | `INTEGER` | 否 | 自增 | 主键 |
| `task_id` | `INTEGER` | 是 | `NULL` | 逻辑关联 `task.id`；任务删除后仍可保留历史记录 |
| `task_title_snapshot` | `TEXT` | 否 | — | 专注开始时保存的任务标题 |
| `started_at` | `INTEGER` | 否 | — | 开始时间，Unix epoch 毫秒 |
| `ended_at` | `INTEGER` | 否 | — | 结束时间，Unix epoch 毫秒 |
| `planned_duration_seconds` | `INTEGER` | 否 | — | 计划时长，单位秒 |
| `actual_duration_seconds` | `INTEGER` | 否 | — | 实际时长，单位秒 |
| `note` | `TEXT` | 是 | `NULL` | 本轮专注笔记 |
| `status` | `TEXT` | 否 | — | `COMPLETED` 或 `CANCELLED` |
| `created_at` | `INTEGER` | 否 | — | 记录创建时间，Unix epoch 毫秒 |

## 使用规则

- 查询历史记录默认按 `started_at DESC, id DESC` 排序。
- Dart 枚举 `FocusSessionStatus.completed/cancelled` 分别映射为 `COMPLETED/CANCELLED`。
- `task_title_snapshot` 是历史展示的兜底数据，不应随着任务标题后续修改而更新。
