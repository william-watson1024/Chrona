import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/focus_settings_provider.dart';
import '../../widgets/chrona_widgets.dart';
import '../history/history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inheritedProvider =
        Provider.of<FocusSettingsProvider?>(context, listen: false);
    if (inheritedProvider != null) return const _SettingsContent();

    return ChangeNotifierProvider(
      create: (_) => FocusSettingsProvider()..load(),
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatelessWidget {
  const _SettingsContent();

  static const _breakOptions = <int>[
    10,
    30,
    60,
    2 * 60,
    3 * 60,
    5 * 60,
    10 * 60,
    15 * 60,
    20 * 60,
    30 * 60,
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Consumer<FocusSettingsProvider>(
                builder: (context, settings, child) {
                  if (settings.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF111111),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    children: [
                      const BrandHeader(showSettingsButton: false),
                      const SizedBox(height: 67),
                      const Text(
                        '设置',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 38,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 54),
                      _DurationSetting(
                        label: '休息时长',
                        value: settings.breakDurationSeconds,
                        options: _breakOptions,
                        onChanged: settings.updateBreakDuration,
                      ),
                    ],
                  );
                },
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 2,
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                }
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class _DurationSetting extends StatelessWidget {
  const _DurationSetting({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DropdownButton<int>(
          value: options.contains(value) ? value : options.last,
          underline: const SizedBox.shrink(),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(_formatDuration(option)),
              ),
          ],
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds 秒';
    return '${seconds ~/ 60} 分钟';
  }
}
