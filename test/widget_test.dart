import 'package:chrona/app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('app starts', (tester) async {
    await tester.pumpWidget(const ChronaApp());

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('C H R O N A'), findsOneWidget);
    expect(find.text('阅读 Orca 论文'), findsOneWidget);
    expect(find.text('添加任务'), findsOneWidget);
  });
}
