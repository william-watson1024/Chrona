# `journal_entry` 日记表

存储用户按天记录的日记内容、反思问题及回答。

## 字段字典

| 字段 | 类型 | 可空 | 默认值 | 说明 |
| --- | --- | --- | --- | --- |
| `id` | `INTEGER` | 否 | 自增 | 主键 |
| `entry_date` | `TEXT` | 否 | — | 日记日期，格式 `YYYY-MM-DD`；唯一 |
| `question_id` | `INTEGER` | 是 | `NULL` | 反思问题标识 |
| `question_text` | `TEXT` | 是 | `NULL` | 反思问题文本快照 |
| `question_answer` | `TEXT` | 是 | `NULL` | 对反思问题的回答 |
| `content` | `TEXT` | 是 | `NULL` | 日记正文 |
| `created_at` | `INTEGER` | 否 | — | 创建时间，Unix epoch 毫秒 |
| `updated_at` | `INTEGER` | 否 | — | 最近更新时间，Unix epoch 毫秒 |

## 使用规则

- `entry_date` 的 `UNIQUE` 约束保证每天最多一条日记。
- 保存日记时，应用先按 `entry_date` 查找；不存在则插入，存在则更新。
- 查询日记默认按 `entry_date DESC, id DESC` 排序。
