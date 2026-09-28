import 'package:chrona/app.dart';
import 'package:chrona/models/focus_session.dart';
import 'package:chrona/models/task.dart';
import 'package:chrona/providers/focus_provider.dart';
import 'package:chrona/providers/focus_settings_provider.dart';
import 'package:chrona/providers/focus_session_provider.dart';
import 'package:chrona/providers/task_provider.dart';
import 'package:chrona/screens/focus/focus_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

TaskProvider createTestTaskProvider() {
  return TaskProvider.inMemory([
    const Task(
      id: 1,
      title: '阅读 Orca 论文',
      note: '继续看 Section 3',
      completed: false,
      createdAt: 1,
    ),
  ]);
}

FocusSessionProvider createTestFocusSessionProvider() {
  return FocusSessionProvider.inMemory();
}

void main() {
  test('calculates today focus duration in hours from real sessions', () {
    final now = DateTime.now();
    final provider = FocusSessionProvider.inMemory([
      FocusSession(
        taskId: 1,
        taskTitleSnapshot: '测试任务',
        startedAt: now.subtract(const Duration(minutes: 10)),
        endedAt: now.subtract(const Duration(minutes: 5)),
        plannedDurationSeconds: 10 * 60,
        actualDurationSeconds: 5 * 60,
        note: null,
        status: FocusSessionStatus.completed,
        createdAt: now,
      ),
    ]);

    expect(provider.todayFocusDurationHours, closeTo(5 / 60, 0.001));
  });

  test('updates only the FocusSession note', () async {
    final now = DateTime.now();
    final session = FocusSession(
      id: 7,
      taskId: 1,
      taskTitleSnapshot: '测试任务',
      startedAt: now.subtract(const Duration(minutes: 25)),
      endedAt: now,
      plannedDurationSeconds: 25 * 60,
      actualDurationSeconds: 25 * 60,
      note: '旧记录',
      status: FocusSessionStatus.completed,
      createdAt: now,
    );
    final provider = FocusSessionProvider.inMemory([session]);

    final updated = await provider.updateSessionNote(session, '新记录');

    expect(updated?.note, '新记录');
    expect(updated?.startedAt, session.startedAt);
    expect(updated?.actualDurationSeconds, session.actualDurationSeconds);
    expect(provider.sessions.single.note, '新记录');
  });

  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('C H R O N A'), findsOneWidget);
    expect(find.text('阅读 Orca 论文'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('添加任务'), 240);
    expect(find.text('添加任务'), findsOneWidget);
  });

  testWidgets('focus demo flow navigates to history', (tester) async {
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('暂停'), 240);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('结束专注'));
    await tester.pumpAndSettle();
    expect(find.text('提前结束本轮专注？'), findsOneWidget);
    await tester.tap(find.text('结束'));
    await tester.pumpAndSettle();
    expect(find.text('本轮记录'), findsOneWidget);

    await tester.enterText(find.byType(TextField), '补充一条 Mock 记录');
    final saveButton = find.text('保存').last;
    await tester.scrollUntilVisible(
      saveButton,
      240,
      scrollable: find.ancestor(
        of: saveButton,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('记录'), findsNWidgets(2));
    await tester.scrollUntilVisible(find.text('阅读 Orca 论文'), 240);
    expect(find.text('阅读 Orca 论文'), findsOneWidget);
    expect(find.text('补充一条 Mock 记录'), findsOneWidget);
  });

  testWidgets('adding a task refreshes the home list', (tester) async {
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    await tester.scrollUntilVisible(find.text('添加任务'), 240);
    await tester.tap(find.text('添加任务'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '新任务');
    await tester.enterText(find.byType(TextField).last, '一条备注');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('新任务'), findsOneWidget);
    expect(find.text('一条备注'), findsOneWidget);
  });

  testWidgets('short focus session finishes and opens the note screen',
      (tester) async {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          task: const Task(
            id: 1,
            title: '测试任务',
            completed: false,
            createdAt: 1,
          ),
          durationSeconds: 1,
          now: () => currentTime,
        ),
      ),
    );
    expect(find.text('00:01'), findsOneWidget);

    currentTime = currentTime.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();

    expect(find.text('本轮专注完成'), findsOneWidget);
    expect(find.text('测试任务'), findsOneWidget);
  });

  testWidgets('completed focus saves and enters break mode', (tester) async {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    final focusProvider = FocusProvider(
      task: const Task(
        id: 1,
        title: '测试任务',
        completed: false,
        createdAt: 1,
      ),
      plannedDurationSeconds: 1,
      now: () => currentTime,
    );
    final sessionProvider = FocusSessionProvider.inMemory();
    final settingsProvider =
        FocusSettingsProvider.inMemory(breakDurationSeconds: 1);

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sessionProvider),
          ChangeNotifierProvider.value(value: settingsProvider),
        ],
        child: MaterialApp(
          home: FocusScreen(
            task: focusProvider.task,
            durationSeconds: 1,
            focusProvider: focusProvider,
          ),
        ),
      ),
    );

    currentTime = currentTime.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('本轮专注完成'), findsOneWidget);

    final saveButton = find.text('保存').last;
    await tester.scrollUntilVisible(
      saveButton,
      240,
      scrollable: find.ancestor(
        of: saveButton,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.text('休息一下'), findsOneWidget);
    expect(find.text('短休息'), findsOneWidget);
    expect(sessionProvider.sessions, hasLength(1));

    final skipBreak = find.text('跳过休息');
    await tester.scrollUntilVisible(
      skipBreak,
      240,
      scrollable: find.ancestor(
        of: skipBreak,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(skipBreak);
    await tester.pump();
    expect(find.text('准备开始下一轮'), findsOneWidget);
    expect(sessionProvider.sessions, hasLength(1));

    focusProvider.dispose();
  });

  testWidgets('pause freezes time and resume rebuilds the end timestamp',
      (tester) async {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    final provider = FocusProvider(
      task: const Task(
        id: 1,
        title: '测试任务',
        completed: false,
        createdAt: 1,
      ),
      plannedDurationSeconds: 30,
      now: () => currentTime,
    );
    provider.start();

    currentTime = currentTime.add(const Duration(seconds: 5));
    provider.pause();
    expect(provider.status, FocusTimerStatus.paused);
    expect(provider.remainingSeconds, 25);
    expect(provider.pausedAt, currentTime);
    expect(provider.pausedRemainingSeconds, 25);

    currentTime = currentTime.add(const Duration(seconds: 10));
    provider.resume();
    expect(provider.status, FocusTimerStatus.running);
    expect(provider.pausedAt, isNull);
    expect(provider.pausedRemainingSeconds, isNull);
    expect(provider.endsAt?.difference(currentTime).inSeconds, 25);

    provider.dispose();
  });

  testWidgets('paused focus resumes after returning to today', (tester) async {
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    await tester.scrollUntilVisible(find.text('暂停'), 240);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_filled));
    await tester.pumpAndSettle();
    expect(find.text('今天'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('继续'), findsOneWidget);
  });
}
