# `daily_question` 每日问题实例表

保存用户某一天实际使用的问题。题库 JSON 是只读默认来源，不导入 SQLite；只有打开、修改或保存当天数据时才按需创建实例。

## 字段字典

| 字段 | 类型 | 可空 | 说明 |
| --- | --- | --- | --- |
| `id` | `INTEGER` | 否 | 主键 |
| `entry_date` | `TEXT` | 否 | 业务日期 `YYYY-MM-DD`，唯一 |
| `source_type` | `TEXT` | 否 | `DAILY`、`SPECIAL`、`BIRTHDAY` 或 `CUSTOM` |
| `source_key` | `TEXT` | 是 | 题目来源键，例如 `9.30`、`mid_autumn`、`birthday` |
| `original_question_text` | `TEXT` | 否 | 首次解析出的默认题目，永久保留 |
| `question_text` | `TEXT` | 否 | 当前用户实际看到的题目 |
| `is_modified` | `INTEGER` | 否 | `0` 未修改，`1` 用户修改过 |
| `created_at` | `INTEGER` | 否 | 创建时间，Unix epoch 毫秒 |
| `updated_at` | `INTEGER` | 否 | 最近更新时间，Unix epoch 毫秒 |

## 使用规则

- `entry_date` 保证每天最多一条最终问题。
- 解析优先级为：已有实例 → 生日 → 特殊日期 → 普通每日一问。
- JSON 更新不会覆盖已经存在的实例；恢复默认时才显式使用 `original_question_text`。
- `journal_entry.question_id` 逻辑关联本表；`journal_entry.question_text` 是旧字段，保留但不再作为新写入来源。
