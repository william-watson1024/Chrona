# 随机问题池实现报告

## 1. 修改文件

- `pubspec.yaml`：注册 `assets/question/拾年随机问题池_4000.json`。
- `lib/models/daily_question.dart`：新增只读 `RandomQuestionDefinition`，并允许保存问题来源切换。
- `lib/repositories/question_repository.dart`：按需读取并缓存随机问题池，解析真实的 `questions` / `id` / `theme` / `question` 结构。
- `lib/services/question_resolver.dart`：拆分 `resolveQuestion()` 与只解析默认来源的 `resolveDefaultQuestion()`。
- `lib/services/question_service.dart`：实现随机换题、最近 20 条防重复、CUSTOM / RANDOM 切换和恢复默认。
- `lib/providers/journal_provider.dart`：提供换题和恢复默认的立即持久化入口，并同步 `journal_entry.question_id`。
- `lib/screens/today/today_screen.dart`：增加“换一个”“恢复默认”操作；已有回答时先确认，换题不清空回答。
- `test/daily_question_test.dart`：增加随机题库有效性测试。

## 2. 随机问题池加载方式

随机题库仍是 Flutter Asset，不进入 SQLite。首次调用 `QuestionRepository.randomQuestions()` 时读取并解析，随后保存在 Repository 内存中；Widget 不直接解析 JSON。

项目实际文件名为 `拾年随机问题池_4000.json`，顶层结构为 `questions` 数组，每条记录包含 `id`、`theme`、`question`。

## 3. 随机算法与防重复策略

`QuestionService` 使用内存中的 `Random` 从题库选择；候选题排除当前问题和最近 20 个随机题 ID。若候选集合因题库规模变化而为空，则退化为仅排除当前问题，避免无题可换。

## 4. DailyQuestion 如何保存 RANDOM

点击“换一个”会先确保当天存在一条 `daily_question`，然后对当天同一行执行更新：

- `source_type = RANDOM`
- `source_key = random:Rxxxx`
- `question_text = 随机题文本`
- `is_modified = 1`
- `original_question_text`、`created_at` 保持不变

随机结果在操作完成前立即写入数据库，不等待保存日记。

## 5. CUSTOM / RANDOM / 默认问题切换

- 默认问题来源按生日 → 特殊日期 → 普通每日一问解析，来源分别为 `BIRTHDAY`、`SPECIAL`、`DAILY`。
- 随机换题为 `RANDOM`。
- 用户手动编辑为 `CUSTOM`，`source_key = custom`。
- `original_question_text` 始终保存当天首次解析出的默认问题。

## 6. 恢复默认

恢复默认会重新调用 `resolveDefaultQuestion()` 获取当天真实默认来源，并将问题文本恢复为保存的 `original_question_text`，同时设置 `is_modified = 0`。因此生日问题不会被错误恢复成 `DAILY`。

## 7. 是否修改数据库 Schema

没有新增表，也没有提升数据库版本。随机题库不建立 `random_question` 或 `question_pool` 表；已选随机问题仍使用现有 `daily_question` 表。

## 8. 备份恢复是否需要调整

不需要额外调整备份格式。现有 `daily_questions` 导出已经包含 `source_type`、`source_key`、`original_question_text`、`question_text`、`is_modified`。恢复后以数据库中的 `question_text` 为历史事实，不根据 `source_key` 重新读取题库。

## 9. 测试结果

- 随机题库读取测试：已增加，验证数量非空、ID 唯一、问题文本非空。
- 随机选择测试：已增加，验证排除当前问题和最近已选问题。
- 既有普通日期、特殊日期、生日优先级和闰年题库测试：保留。
- `flutter test --no-pub`：17 项测试全部通过。

## 10. flutter analyze 结果

`flutter analyze --no-pub`：`No issues found!`。

## 11. 尚未解决的问题

目前没有已知功能性遗留问题。
