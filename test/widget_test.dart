import 'package:chrona/app.dart';
import 'package:chrona/models/task.dart';
import 'package:chrona/providers/task_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

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

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(ChronaApp(taskProvider: createTestTaskProvider()));

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('C H R O N A'), findsOneWidget);
    expect(find.text('阅读 Orca 论文'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('添加任务'), 240);
    expect(find.text('添加任务'), findsOneWidget);
  });

  testWidgets('focus demo flow navigates to history', (tester) async {
    await tester.pumpWidget(ChronaApp(taskProvider: createTestTaskProvider()));

    await tester.tap(find.byIcon(Icons.play_arrow_rounded).first);
    await tester.pumpAndSettle();
    expect(find.text('24:37'), findsOneWidget);

    await tester.scrollUntilVisible(find.text('暂停'), 240);
    await tester.tap(find.text('暂停'));
    await tester.pump();
    expect(find.text('继续'), findsOneWidget);

    await tester.tap(find.text('结束专注'));
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
    expect(find.text('20:00 — 20:25'), findsOneWidget);
  });

  testWidgets('adding a task refreshes the home list', (tester) async {
    await tester.pumpWidget(ChronaApp(taskProvider: createTestTaskProvider()));

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
}
