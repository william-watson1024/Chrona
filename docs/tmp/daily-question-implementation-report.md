# 每日一问实现报告

## 1. 修改文件

- `lib/models/daily_question.dart`：新增 `DailyQuestion` 与只读 `QuestionDefinition`。
- `lib/repositories/question_repository.dart`：读取并缓存两个题库 JSON，解析普通、特殊、农历、节气、星期规则和生日规则。
- `lib/services/question_resolver.dart`：统一实现已有实例 → 生日 → 特殊日期 → 普通每日一问的优先级。
- `lib/services/question_service.dart`：按需创建问题实例、保存用户修改、恢复原始默认题目。
- `lib/database/app_database.dart`：数据库版本 7→8、`daily_question` CRUD、历史迁移和备份兼容导入。
- `lib/providers/journal_provider.dart` 与日记页：以 `question_id` / `daily_question` 为正式问题来源。
- `lib/services/birthday_settings.dart` 与设置页：使用 `SharedPreferences` 保存生日月日、修改和清除。
- `lib/services/data_transfer_service.dart`：备份和恢复 `daily_question` 与生日设置。
- `pubspec.yaml`：声明两个题库 JSON assets。
- `test/daily_question_test.dart`：普通题目、特殊日期、生日优先级和闰年题库测试。

## 2. Schema migration

schema 7 升级到 8 时创建 `daily_question`。对已有非空 `journal_entry.question_text`，按 `entry_date` 创建 `CUSTOM / legacy` 实例，沿用旧记录的创建和更新时间，并回填 `journal_entry.question_id`。空问题不创建实例；回答、日记正文和原有 `created_at` 不被覆盖。迁移不删除数据库、不清空业务数据。

## 3. 问题解析规则

打开日期时先查 SQLite 中是否存在 `daily_question`。不存在时只在内存中解析题库：生日优先，其次特殊日期，最后普通每日一问。普通题库按 `月.日` 和年份读取；特殊题库按 JSON 的 `calendar` / `rule` 读取。农历和清明采用题库覆盖范围 2026–2036 的可审查映射；除夕按春节前一天计算，不假设腊月三十。

## 4. 生日存储

仅保存 `birthday_month` 和 `birthday_day`，不保存出生年份。未设置时不命中生日题目；设置页支持显示、修改和清除。

## 5. 备份兼容

新备份额外包含 `daily_questions` 和生日设置。旧版本备份没有 `daily_questions` 时仍可导入；导入非空的旧 `journal_entry.question_text` 会重建 `CUSTOM / legacy` 问题实例并补齐 `question_id`。备份协议仍保持 `chrona_backup` version 1。

## 6. 自动检查

- `dart format lib test`：通过。
- `dart analyze`：通过，无问题。
- `flutter analyze --no-pub`：通过，无问题。
- `flutter test --no-pub`：通过，14 个测试全部通过。

## 7. 尚需人工确认

- 在真实设备上验证 SQLite v7 数据库升级和备份导入后的页面刷新。
- 在 2026–2036 的题库覆盖范围内逐项抽查农历节日和清明日期。
- 验收设置页生日选择器、清除生日，以及生日与情人节同日时生日题目优先显示。
