import 'package:flutter/material.dart';

import 'theme/app_theme.dart';

class ChronaApp extends StatelessWidget {
  const ChronaApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CHRONA',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      home: const _StarterScreen(),
    );
  }
}

class _StarterScreen extends StatelessWidget {
  const _StarterScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('CHRONA'),
      ),
    );
  }
}

