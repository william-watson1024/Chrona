import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_session_provider.dart';
import '../../utils/focus_formatters.dart';
import '../../widgets/chrona_widgets.dart';
import '../../widgets/focus_session_entry.dart';
import '../settings/settings_screen.dart';
import 'day_detail_screen.dart';
import 'record_detail_screen.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inheritedProvider =
        Provider.of<FocusSessionProvider?>(context, listen: false);
    if (inheritedProvider != null) return const _HistoryContent();

    return ChangeNotifierProvider(
      create: (_) => FocusSessionProvider()..loadSessions(),
      child: const _HistoryContent(),
    );
  }
}

class _HistoryContent extends StatelessWidget {
  const _HistoryContent();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Consumer<FocusSessionProvider>(
                builder: (context, provider, child) {
                  if (provider.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF111111),
                      ),
                    );
                  }

                  final groups = _groupSessions(provider.sessions);
                  final week = _WeekSummary.fromSessions(
                    provider.sessions,
                    DateTime.now(),
                  );

                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    children: [
                      BrandHeader(
                        onSettingsPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const SettingsScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: 67),
                      _WeekOverview(
                        summary: week,
                        onDayTap: (date) => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => DayDetailScreen(date: date),
                          ),
                        ),
                      ),
                      const SizedBox(height: 36),
                      const Divider(color: Color(0xFFE4E4E4)),
                      const SizedBox(height: 34),
                      if (groups.isEmpty)
                        const Text(
                          '还没有专注记录',
                          style: TextStyle(
                            color: Color(0xFF858585),
                            fontSize: 18,
                          ),
                        )
                      else
                        for (var index = 0; index < groups.length; index++) ...[
                          _HistoryGroup(
                            group: groups[index],
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => DayDetailScreen(
                                  date: groups[index].date,
                                ),
                              ),
                            ),
                          ),
                          if (index != groups.length - 1)
                            const SizedBox(height: 42),
                        ],
                    ],
                  );
                },
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 1,
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
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

  List<_HistoryDayGroup> _groupSessions(List<FocusSession> sessions) {
    final groups = <String, _HistoryDayGroup>{};
    for (final session in sessions) {
      final date = session.startedAt;
      final key = '${date.year}-${date.month}-${date.day}';
      groups
          .putIfAbsent(
            key,
            () => _HistoryDayGroup(date: date, sessions: []),
          )
          .sessions
          .add(session);
    }
    return groups.values.toList();
  }
}

class _WeekSummary {
  _WeekSummary({required this.weekStart, required this.sessions})
      : daySeconds = List<int>.filled(7, 0),
        daySessions = List<List<FocusSession>>.generate(7, (_) => []);

  factory _WeekSummary.fromSessions(
    List<FocusSession> sessions,
    DateTime date,
  ) {
    final weekStart = startOfFocusWeek(date);
    final summary = _WeekSummary(
      weekStart: weekStart,
      sessions: sessions
          .where((session) =>
              !session.startedAt.isBefore(weekStart) &&
              session.startedAt
                  .isBefore(weekStart.add(const Duration(days: 7))))
          .toList(growable: false),
    );

    for (final session in summary.sessions) {
      final index = session.startedAt.difference(weekStart).inDays;
      if (index < 0 || index > 6) continue;
      summary.daySeconds[index] += session.actualDurationSeconds;
      summary.daySessions[index].add(session);
    }
    return summary;
  }

  final DateTime weekStart;
  final List<FocusSession> sessions;
  final List<int> daySeconds;
  final List<List<FocusSession>> daySessions;

  int get totalSeconds => daySeconds.fold(0, (total, value) => total + value);
  int get count => sessions.length;
  int get averageSeconds => totalSeconds ~/ 7;

  int get longestDayIndex {
    var index = 0;
    for (var current = 1; current < daySeconds.length; current++) {
      if (daySeconds[current] > daySeconds[index]) index = current;
    }
    return index;
  }

  DateTime dateAt(int index) => weekStart.add(Duration(days: index));
}

class _WeekOverview extends StatelessWidget {
  const _WeekOverview({required this.summary, required this.onDayTap});

  final _WeekSummary summary;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final longestSeconds = summary.daySeconds[summary.longestDayIndex];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '本周',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 31,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    '${summary.weekStart.month}月${summary.weekStart.day}日—'
                    '${summary.dateAt(6).month}月${summary.dateAt(6).day}日',
                    style: const TextStyle(
                      color: Color(0xFF858585),
                      fontSize: 16,
                      height: 1.1,
                    ),
                  ),
                ],
              ),
            ),
            _WeekStat(
              value: formatFocusHoursMinutes(summary.totalSeconds),
              label: '专注时长',
            ),
            const SizedBox(width: 25),
            _WeekStat(value: '${summary.count}', label: '专注次数'),
          ],
        ),
        const SizedBox(height: 39),
        SizedBox(
          height: 184,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var index = 0; index < 7; index++)
                Expanded(
                  child: _WeekBar(
                    date: summary.dateAt(index),
                    seconds: summary.daySeconds[index],
                    onTap: () => onDayTap(summary.dateAt(index)),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 28),
        Row(
          children: [
            Expanded(
              child: _WeekStat(
                value: formatFocusHoursMinutes(summary.averageSeconds),
                label: '平均每天',
                alignStart: true,
              ),
            ),
            Container(width: 1, height: 54, color: const Color(0xFFE4E4E4)),
            Expanded(
              child: _WeekStat(
                value: summary.count == 0
                    ? '—'
                    : '${_weekday(summary.longestDayIndex)} · '
                        '${formatFocusHoursMinutes(longestSeconds)}',
                label: '最长一天',
                alignStart: true,
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _weekday(int index) =>
      const ['一', '二', '三', '四', '五', '六', '日'][index];
}

class _WeekBar extends StatelessWidget {
  const _WeekBar({
    required this.date,
    required this.seconds,
    required this.onTap,
  });

  final DateTime date;
  final int seconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    const fullScaleSeconds = 8 * Duration.secondsPerHour;
    const chartHeight = 156.0;
    const minimumBarPixels = 2.0;
    final rawFraction = seconds / fullScaleSeconds;
    final fraction = seconds <= 0
        ? 0.0
        : rawFraction.clamp(minimumBarPixels / chartHeight, 1.0);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onTap,
      child: Column(
        children: [
          Expanded(
            child: Center(
              child: SizedBox(
                width: 42,
                height: 156,
                child: Align(
                  alignment: Alignment.bottomCenter,
                  child: Container(
                    width: 42,
                    height: 156,
                    decoration: BoxDecoration(
                      color: const Color(0xFFF1F1F1),
                      borderRadius: BorderRadius.circular(3),
                    ),
                    alignment: Alignment.bottomCenter,
                    child: FractionallySizedBox(
                      widthFactor: 1,
                      heightFactor: fraction,
                      alignment: Alignment.bottomCenter,
                      child: Container(
                        decoration: BoxDecoration(
                          color: const Color(0xFF111111),
                          borderRadius: BorderRadius.circular(3),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            _weekday(date.weekday),
            style: const TextStyle(color: Color(0xFF858585), fontSize: 17),
          ),
        ],
      ),
    );
  }

  String _weekday(int weekday) =>
      const ['一', '二', '三', '四', '五', '六', '日'][weekday - 1];
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({
    required this.value,
    required this.label,
    this.alignStart = false,
  });

  final String value;
  final String label;
  final bool alignStart;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment:
          alignStart ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      children: [
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 27,
            height: 1.05,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 9),
        Text(
          label,
          style: const TextStyle(color: Color(0xFF858585), fontSize: 16),
        ),
      ],
    );
  }
}

class _HistoryDayGroup {
  _HistoryDayGroup({required this.date, required this.sessions});

  final DateTime date;
  final List<FocusSession> sessions;

  int get totalSeconds => sessions.fold(
        0,
        (total, session) => total + session.actualDurationSeconds,
      );
}

class _HistoryGroup extends StatelessWidget {
  const _HistoryGroup({required this.group, required this.onTap});

  final _HistoryDayGroup group;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  formatFocusDayHeading(group.date),
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 32,
                    height: 1.1,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  '${group.sessions.length} 次专注 · '
                  '${formatFocusHoursMinutes(group.totalSeconds)}',
                  style: const TextStyle(
                    color: Color(0xFF858585),
                    fontSize: 18,
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        for (final session in group.sessions)
          FocusSessionEntry(
            session: session,
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => RecordDetailScreen(session: session),
              ),
            ),
          ),
      ],
    );
  }
}
