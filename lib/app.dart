import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/focus_session_provider.dart';
import 'providers/task_provider.dart';
import 'screens/today/today_screen.dart';
import 'theme/app_theme.dart';

class ChronaApp extends StatelessWidget {
  const ChronaApp({super.key, this.taskProvider, this.focusSessionProvider});

  final TaskProvider? taskProvider;
  final FocusSessionProvider? focusSessionProvider;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
        title: 'CHRONA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: TodayScreen(taskProvider: taskProvider));

    if (focusSessionProvider != null) {
      return ChangeNotifierProvider.value(
        value: focusSessionProvider!,
        child: app,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => FocusSessionProvider()..loadSessions(),
      child: app,
    );
  }
}
