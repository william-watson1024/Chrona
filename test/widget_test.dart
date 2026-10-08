import 'package:chrona/app.dart';
import 'package:chrona/models/focus_session.dart';
import 'package:chrona/models/task.dart';
import 'package:chrona/providers/focus_provider.dart';
import 'package:chrona/providers/focus_settings_provider.dart';
import 'package:chrona/providers/focus_session_provider.dart';
import 'package:chrona/providers/task_provider.dart';
import 'package:chrona/screens/focus/focus_screen.dart';
import 'package:chrona/screens/history/history_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

TaskProvider createTestTaskProvider() {
  return TaskProvider.inMemory([
    const Task(
      id: 1,
      title: '测试任务',
      note: '测试备注',
      completed: false,
      createdAt: 1,
    ),
  ]);
}

FocusSessionProvider createTestFocusSessionProvider() {
  return FocusSessionProvider.inMemory();
}

void resetFocusPreferences() {
  SharedPreferences.setMockInitialValues({});
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
    expect(find.text('测试任务'), findsOneWidget);

    final addTask = find.text('添加任务');
    await tester.scrollUntilVisible(
      addTask,
      240,
      scrollable:
          find.ancestor(of: addTask, matching: find.byType(Scrollable)).last,
    );
    expect(find.text('添加任务'), findsOneWidget);
  });

  testWidgets('focus demo flow navigates to history', (tester) async {
    resetFocusPreferences();
    final focusSessionProvider = createTestFocusSessionProvider();
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: focusSessionProvider,
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('25:00'), findsOneWidget);

    final pauseButton = find.text('暂停');
    await tester.scrollUntilVisible(
      pauseButton,
      240,
      scrollable: find
          .ancestor(of: pauseButton, matching: find.byType(Scrollable))
          .last,
    );
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('结束专注'));
    await tester.pumpAndSettle();
    expect(find.text('提前结束本轮专注？'), findsOneWidget);
    await tester.tap(find.text('结束'));
    await tester.pumpAndSettle();
    expect(find.text('本轮记录'), findsOneWidget);

    await tester.enterText(find.byType(TextField).last, '补充一条测试记录');
    final saveButton = find.text('保存').last;
    await tester.scrollUntilVisible(
      saveButton,
      240,
      scrollable:
          find.ancestor(of: saveButton, matching: find.byType(Scrollable)).last,
    );
    await tester.tap(saveButton);
    await tester.pumpAndSettle();
    expect(find.byType(HistoryScreen), findsOneWidget);
    expect(focusSessionProvider.sessions, hasLength(1));
    expect(focusSessionProvider.sessions.single.note, '补充一条测试记录');
  });

  testWidgets('adding a task refreshes the home list', (tester) async {
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    final addTask = find.text('添加任务');
    await tester.scrollUntilVisible(
      addTask,
      240,
      scrollable:
          find.ancestor(of: addTask, matching: find.byType(Scrollable)).last,
    );
    await tester.tap(find.text('添加任务'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '新任务');
    await tester.enterText(find.byType(TextField).last, '一条备注');
    await tester.tap(find.text('添加'));
    await tester.pumpAndSettle();

    expect(find.text('新任务'), findsOneWidget);
    expect(find.text('25m'), findsNWidgets(2));
    expect(find.byIcon(Icons.schedule_outlined), findsNWidgets(2));
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

  test('delayed lifecycle refresh finishes at the original end timestamp', () {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    final provider = FocusProvider(
      task: const Task(
        id: 1,
        title: '测试任务',
        completed: false,
        createdAt: 1,
      ),
      plannedDurationSeconds: 25 * 60,
      now: () => currentTime,
    );

    provider.start();
    currentTime = currentTime.add(const Duration(minutes: 28, seconds: 13));
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(provider.status, FocusTimerStatus.finished);
    expect(provider.remainingSeconds, 0);
    expect(
      provider.endedAt,
      DateTime(2026, 9, 27, 20, 25),
    );
    expect(provider.actualDurationSeconds, 25 * 60);

    provider.dispose();
  });

  test('paused time is excluded from a completed focus session', () {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    final provider = FocusProvider(
      task: const Task(
        id: 1,
        title: '测试任务',
        completed: false,
        createdAt: 1,
      ),
      plannedDurationSeconds: 10,
      now: () => currentTime,
    );

    provider.start();
    currentTime = currentTime.add(const Duration(milliseconds: 3500));
    provider.pause();
    currentTime = currentTime.add(const Duration(minutes: 1));
    provider.resume();
    currentTime = provider.endsAt!;
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(provider.status, FocusTimerStatus.finished);
    expect(provider.endedAt, currentTime);
    expect(provider.actualDurationSeconds, 10);
    provider.dispose();
  });

  test('focus extensions accumulate in one round and exclude note time', () {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    const task = Task(
      id: 1,
      title: '测试任务',
      completed: false,
      createdAt: 1,
      durationSeconds: 25 * 60,
    );
    final provider = FocusProvider(
      task: task,
      plannedDurationSeconds: task.durationSeconds,
      now: () => currentTime,
    );

    provider.start();
    currentTime = provider.endsAt!;
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(provider.status, FocusTimerStatus.finished);

    currentTime = currentTime.add(const Duration(minutes: 2));
    provider.extendFocus(10 * 60);
    expect(provider.plannedDurationSeconds, 35 * 60);
    expect(provider.remainingSeconds, 10 * 60);
    expect(provider.actualDurationSeconds, 25 * 60);
    currentTime = provider.endsAt!;
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);
    expect(provider.actualDurationSeconds, 35 * 60);

    currentTime = currentTime.add(const Duration(minutes: 1));
    provider.extendFocus(5 * 60);
    expect(provider.plannedDurationSeconds, 40 * 60);
    currentTime = provider.endsAt!;
    provider.didChangeAppLifecycleState(AppLifecycleState.resumed);

    expect(provider.sessionResult.startedAt, DateTime(2026, 9, 27, 20, 0));
    expect(provider.sessionResult.plannedDurationSeconds, 40 * 60);
    expect(provider.sessionResult.actualDurationSeconds, 40 * 60);
    expect(task.durationSeconds, 25 * 60);
    expect(provider.status, FocusTimerStatus.finished);
    provider.dispose();
  });

  testWidgets('record screen extension resumes the same focus timer',
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

    currentTime = currentTime.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('延长专注'), findsOneWidget);

    final extendButton = find.text('延长专注');
    await tester.scrollUntilVisible(
      extendButton,
      240,
      scrollable: find
          .ancestor(of: extendButton, matching: find.byType(Scrollable))
          .last,
    );
    await tester.tap(find.text('延长专注'));
    await tester.pumpAndSettle();
    expect(find.text('延长 5 分钟'), findsOneWidget);
    await tester.tap(find.text('延长 5 分钟'));
    await tester.pumpAndSettle();

    expect(find.text('05:00'), findsOneWidget);
    expect(find.text('测试任务'), findsOneWidget);
  });

  testWidgets('long rest uses the long rest label without short rest text',
      (tester) async {
    final currentTime = DateTime(2026, 9, 27, 20, 0);
    await tester.pumpWidget(
      MaterialApp(
        home: FocusScreen(
          task: const Task(
            id: 1,
            title: '测试任务',
            completed: false,
            createdAt: 1,
          ),
          durationSeconds: 15 * 60,
          mode: FocusMode.rest,
          now: () => currentTime,
        ),
      ),
    );

    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('长休息'), findsOneWidget);
    expect(find.text('短休息'), findsNothing);
  });

  test('saving the same focus session twice is idempotent', () async {
    final provider = FocusSessionProvider.inMemory();
    final startedAt = DateTime(2026, 9, 27, 20, 0);
    final session = FocusSession(
      taskId: 1,
      taskTitleSnapshot: '测试任务',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(seconds: 30)),
      plannedDurationSeconds: 30,
      actualDurationSeconds: 30,
      note: null,
      status: FocusSessionStatus.completed,
      createdAt: startedAt.add(const Duration(seconds: 30)),
    );

    await provider.saveSessionIfAbsent(session);
    await provider.saveSessionIfAbsent(session);

    expect(provider.sessions, hasLength(1));
  });

  test('extending a saved round updates one historical focus session',
      () async {
    final provider = FocusSessionProvider.inMemory();
    final startedAt = DateTime(2026, 9, 27, 20, 0);
    final firstSegment = FocusSession(
      taskId: 1,
      taskTitleSnapshot: '测试任务',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 25)),
      plannedDurationSeconds: 25 * 60,
      actualDurationSeconds: 25 * 60,
      note: null,
      status: FocusSessionStatus.completed,
      createdAt: startedAt.add(const Duration(minutes: 25)),
    );
    final extendedRound = FocusSession(
      taskId: 1,
      taskTitleSnapshot: '测试任务',
      startedAt: startedAt,
      endedAt: startedAt.add(const Duration(minutes: 35)),
      plannedDurationSeconds: 35 * 60,
      actualDurationSeconds: 35 * 60,
      note: null,
      status: FocusSessionStatus.completed,
      createdAt: startedAt.add(const Duration(minutes: 25)),
    );

    await provider.saveOrUpdateRound(firstSegment);
    await provider.saveOrUpdateRound(extendedRound);

    expect(provider.sessions, hasLength(1));
    expect(provider.sessions.single.startedAt, startedAt);
    expect(provider.sessions.single.actualDurationSeconds, 35 * 60);
    expect(provider.completedFocusCountForDay(startedAt), 1);
  });

  testWidgets('completed focus saves and enters break mode', (tester) async {
    resetFocusPreferences();
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
    final taskProvider = createTestTaskProvider();

    await tester.pumpWidget(
      MultiProvider(
        providers: [
          ChangeNotifierProvider.value(value: sessionProvider),
          ChangeNotifierProvider.value(value: settingsProvider),
          ChangeNotifierProvider.value(value: taskProvider),
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

    expect(taskProvider.focusedTaskId, 1);

    currentTime = currentTime.add(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    await tester.pumpAndSettle();
    expect(find.text('本轮专注完成'), findsOneWidget);
    expect(taskProvider.focusedTaskId, isNull);

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
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('休息中'), findsOneWidget);
    expect(find.text('短休息'), findsOneWidget);
    expect(find.text('专注中'), findsNothing);
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

    final startNextFocus = find.text('开始专注');
    await tester.scrollUntilVisible(
      startNextFocus,
      240,
      scrollable: find.ancestor(
        of: startNextFocus,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(startNextFocus);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(taskProvider.focusedTaskId, 1);
    expect(find.text('25:00'), findsOneWidget);
    expect(find.text('休息中'), findsOneWidget);

    focusProvider.dispose();
  });

  testWidgets('next focus round shows its task state when returning to today',
      (tester) async {
    resetFocusPreferences();
    final taskProvider = TaskProvider.inMemory([
      const Task(
        id: 1,
        title: '测试任务',
        completed: false,
        durationSeconds: 1,
        createdAt: 1,
      ),
    ]);
    final sessionProvider = FocusSessionProvider.inMemory();
    final settingsProvider =
        FocusSettingsProvider.inMemory(breakDurationSeconds: 1);

    await tester.pumpWidget(
      ChronaApp(
        taskProvider: taskProvider,
        focusSessionProvider: sessionProvider,
        focusSettingsProvider: settingsProvider,
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 1200)),
    );
    await tester.pump(const Duration(seconds: 2));
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
    expect(find.text('休息中'), findsOneWidget);

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
    await tester.pumpAndSettle();
    final startNextFocus = find.text('开始专注');
    await tester.scrollUntilVisible(
      startNextFocus,
      240,
      scrollable: find.ancestor(
        of: startNextFocus,
        matching: find.byType(Scrollable),
      ),
    );
    await tester.tap(startNextFocus);
    await tester.pumpAndSettle();
    expect(taskProvider.focusedTaskId, 1);

    await tester.tap(find.byTooltip('返回').first);
    await tester.pumpAndSettle();
    expect(find.text('正在专注'), findsOneWidget);
    expect(taskProvider.focusedTaskId, 1);
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

  test('discarding a paused timer clears its state without ending a session',
      () {
    var currentTime = DateTime(2026, 9, 27, 20, 0);
    final provider = FocusProvider(
      task: const Task(
        id: 1,
        title: '娴嬭瘯浠诲姟',
        completed: false,
        createdAt: 1,
      ),
      plannedDurationSeconds: 30,
      now: () => currentTime,
    );
    provider.start();
    currentTime = currentTime.add(const Duration(seconds: 5));
    provider.pause();

    provider.discardPaused();

    expect(provider.status, FocusTimerStatus.idle);
    expect(provider.startedAt, isNull);
    expect(provider.pausedRemainingSeconds, isNull);
    expect(provider.remainingSeconds, 30);
    provider.dispose();
  });

  testWidgets('starting another task discards a paused timer', (tester) async {
    resetFocusPreferences();
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: TaskProvider.inMemory([
          const Task(
            id: 1,
            title: '娴嬭瘯浠诲姟',
            completed: false,
            createdAt: 1,
          ),
          const Task(
            id: 2,
            title: 'Next task',
            completed: false,
            createdAt: 2,
          ),
        ]),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    final pauseButton = find.text('暂停');
    await tester.scrollUntilVisible(
      pauseButton,
      240,
      scrollable: find
          .ancestor(of: pauseButton, matching: find.byType(Scrollable))
          .last,
    );
    await tester.tap(pauseButton);
    await tester.pump();
    await tester.tap(find.byIcon(Icons.home_filled).first);
    await tester.pumpAndSettle();

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).last);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('Next task'), findsOneWidget);
    expect(find.text('暂停'), findsOneWidget);
  });

  testWidgets('paused focus resumes after returning to today', (tester) async {
    resetFocusPreferences();
    await tester.pumpWidget(
      ChronaApp(
        taskProvider: createTestTaskProvider(),
        focusSessionProvider: createTestFocusSessionProvider(),
      ),
    );

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    final pauseButton = find.text('暂停');
    await tester.scrollUntilVisible(
      pauseButton,
      240,
      scrollable: find
          .ancestor(of: pauseButton, matching: find.byType(Scrollable))
          .last,
    );
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.byIcon(Icons.home_filled).last);
    await tester.pumpAndSettle();
    expect(find.text('今朝'), findsNWidgets(2));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('继续'), findsOneWidget);
  });
}
