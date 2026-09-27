import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/focus_session_provider.dart';
import 'providers/focus_settings_provider.dart';
import 'providers/task_provider.dart';
import 'screens/today/today_screen.dart';
import 'theme/app_theme.dart';

class ChronaApp extends StatelessWidget {
  const ChronaApp({
    super.key,
    this.taskProvider,
    this.focusSessionProvider,
    this.focusSettingsProvider,
  });

  final TaskProvider? taskProvider;
  final FocusSessionProvider? focusSessionProvider;
  final FocusSettingsProvider? focusSettingsProvider;

  @override
  Widget build(BuildContext context) {
    final app = MaterialApp(
        title: 'CHRONA',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: TodayScreen(taskProvider: taskProvider));

    final focusSessionApp = focusSessionProvider != null
        ? ChangeNotifierProvider.value(
            value: focusSessionProvider!,
            child: app,
          )
        : ChangeNotifierProvider(
            create: (_) => FocusSessionProvider()..loadSessions(),
            child: app,
          );

    if (focusSettingsProvider != null) {
      return ChangeNotifierProvider.value(
        value: focusSettingsProvider!,
        child: focusSessionApp,
      );
    }

    return ChangeNotifierProvider(
      create: (_) => FocusSettingsProvider()..load(),
      child: focusSessionApp,
    );
  }
}
