import 'package:flutter/material.dart';

import 'providers/task_provider.dart';
import 'screens/today/today_screen.dart';
import 'theme/app_theme.dart';

class ChronaApp extends StatelessWidget {
  const ChronaApp({super.key, this.taskProvider});

  final TaskProvider? taskProvider;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHRONA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: TodayScreen(taskProvider: taskProvider),
    );
  }
}
