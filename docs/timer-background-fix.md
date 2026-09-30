# CHRONA 后台计时修复记录

## 1. 原 BUG 原因

计时状态只存在于运行中的 `FocusProvider`，后台或进程被回收后无法恢复；页面销毁还会取消通知。结束时如果使用恢复时的当前时间作为 `endedAt`，会把后台停留时间错误地计入本轮专注。

## 2. 修改后的计时架构

- 每轮计时以 `startedAt`、`endsAt` 和 `plannedDurationSeconds` 为准。
- 前台 `Timer.periodic` 只负责刷新 UI，不作为真实时间来源。
- 每次刷新按 `max(endsAt - now, 0)` 计算剩余时间。
- 完成时使用原始 `endsAt` 作为 `endedAt`，保证 25 分钟不会变成 28 分钟。
- 活动专注/休息会话写入 `SharedPreferences`，进程重启后按时间戳恢复。
- 结束、取消、跳过休息和通知调度均通过已有 `NotificationService`，Provider 销毁不会取消活动计时。

Android 通知使用系统 chronometer 展示持续倒计时；结束提醒使用已有 `flutter_local_notifications` 的系统定时通知。两者共用同一个 `endsAt`，不需要 Dart isolate 在后台每秒运行。

结束提醒使用新的 Android notification channel，初始震动为每秒一次、持续至少十秒，并设置持续提醒标志及“停止提醒”操作，直到用户主动取消通知。

## 3. 修改文件

- `lib/providers/focus_provider.dart`
  - 增加活动会话持久化与恢复。
  - 修正延迟刷新、生命周期恢复和完成时间计算。
  - 保持专注/休息共用同一套时间戳逻辑。
  - 移除 Provider `dispose` 对后台通知的误取消。
- `lib/services/notification_service.dart`
  - 增加 ongoing 系统倒计时通知。
  - 结束提醒优先使用 exact alarm；无权限时回退到 idle-safe inexact alarm。
- `lib/screens/today/today_screen.dart`
  - App 启动后恢复活动会话并重新打开计时页。
- `android/app/src/main/AndroidManifest.xml`
  - 增加 `SCHEDULE_EXACT_ALARM` 声明。
- `test/widget_test.dart`
  - 增加后台延迟 28 分钟后仍在原始 25 分钟结束的回归测试。

## 4. 新增依赖

没有新增依赖，复用了项目现有的 `SharedPreferences`、`flutter_local_notifications` 和 Android 通知接收器。

## 5. Android 权限/配置

- 已有 `POST_NOTIFICATIONS`、`VIBRATE`、`RECEIVE_BOOT_COMPLETED` 保持不变。
- 新增 `SCHEDULE_EXACT_ALARM`，启动计时时尝试请求精确闹钟权限。
- 用户未授予精确闹钟权限时，系统定时提醒回退到 `inexactAllowWhileIdle`；App 内部状态仍以 `endsAt` 为准。
- 没有新增 Foreground Service。当前计时不需要后台持续执行代码，系统通知 chronometer 和定时通知即可完成展示与提醒；这样也避免引入 Android 14/15 的 FGS 类型、后台启动和时限约束。
- 通知使用公开锁屏可见性、ongoing、不可自动滑除和系统倒计时。

## 6. 测试结果

- `flutter analyze --no-pub`：通过，无问题。
- `flutter test --no-pub`：通过，10 个测试全部通过。
- `flutter build apk --debug`：通过，生成 `build/app/outputs/flutter-apk/app-debug.apk`。

构建时有 Flutter 关于 Kotlin Gradle Plugin 未来迁移的警告；该警告来自现有 Android/插件结构，不是本次计时改动导致的编译错误。

## 7. 尚未自动验证、必须真机测试的内容

- Android 15 真机锁屏后的通知 chronometer 显示。
- 首次授予/拒绝通知权限和精确闹钟权限后的提醒行为。
- 切换到其他 App、深度息屏、电池优化和厂商后台限制下的到点提醒。
- Android 进程被系统回收后重新打开 App 的恢复流程。
- 用户手动停止、取消通知和重复打开 App 时是否符合具体机型的通知行为。
