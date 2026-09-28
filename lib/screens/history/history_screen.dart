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

enum _HistoryGranularity { week, month, year }

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

class _HistoryContent extends StatefulWidget {
  const _HistoryContent();

  @override
  State<_HistoryContent> createState() => _HistoryContentState();
}

class _HistoryContentState extends State<_HistoryContent> {
  _HistoryGranularity _granularity = _HistoryGranularity.week;
  DateTime _periodAnchor = _dateOnly(DateTime.now());

  void _selectGranularity(_HistoryGranularity value) {
    setState(() {
      _granularity = value;
      _periodAnchor = _dateOnly(DateTime.now());
    });
  }

  void _movePeriod(int amount) {
    setState(() {
      switch (_granularity) {
        case _HistoryGranularity.week:
          _periodAnchor = _periodAnchor.add(Duration(days: amount * 7));
        case _HistoryGranularity.month:
          _periodAnchor = DateTime(
            _periodAnchor.year,
            _periodAnchor.month + amount,
            1,
          );
        case _HistoryGranularity.year:
          _periodAnchor = DateTime(_periodAnchor.year + amount, 1, 1);
      }
    });
  }

  void _openMonth(DateTime month) {
    setState(() {
      _granularity = _HistoryGranularity.month;
      _periodAnchor = DateTime(month.year, month.month, 1);
    });
  }

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

                  final sessions = _sessionsForPeriod(provider.sessions);
                  final groups = _groupSessions(sessions);

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
                      const SizedBox(height: 30),
                      _PeriodSelector(
                        title: _periodTitle(),
                        onPrevious: () => _movePeriod(-1),
                        onNext: () => _movePeriod(1),
                        onSelected: _selectGranularity,
                      ),
                      const SizedBox(height: 32),
                      _buildPeriodView(sessions),
                      if (_granularity != _HistoryGranularity.year) ...[
                        const SizedBox(height: 36),
                        const Divider(color: Color(0xFFE4E4E4)),
                        const SizedBox(height: 34),
                        if (groups.isEmpty)
                          const _EmptyHistory()
                        else
                          for (var index = 0;
                              index < groups.length;
                              index++) ...[
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

  Widget _buildPeriodView(List<FocusSession> sessions) {
    switch (_granularity) {
      case _HistoryGranularity.week:
        return _WeekOverview(
          summary: _WeekSummary.fromSessions(sessions, _periodStart),
          onDayTap: (date) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DayDetailScreen(date: date)),
          ),
        );
      case _HistoryGranularity.month:
        return _MonthOverview(
          month: _periodStart,
          sessions: sessions,
          onDayTap: (date) => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => DayDetailScreen(date: date)),
          ),
        );
      case _HistoryGranularity.year:
        return _YearOverview(
          year: _periodStart.year,
          sessions: sessions,
          onMonthTap: _openMonth,
        );
    }
  }

  DateTime get _periodStart {
    switch (_granularity) {
      case _HistoryGranularity.week:
        return startOfFocusWeek(_periodAnchor);
      case _HistoryGranularity.month:
        return DateTime(_periodAnchor.year, _periodAnchor.month, 1);
      case _HistoryGranularity.year:
        return DateTime(_periodAnchor.year, 1, 1);
    }
  }

  DateTime get _periodEnd {
    switch (_granularity) {
      case _HistoryGranularity.week:
        return _periodStart.add(const Duration(days: 7));
      case _HistoryGranularity.month:
        return DateTime(_periodStart.year, _periodStart.month + 1, 1);
      case _HistoryGranularity.year:
        return DateTime(_periodStart.year + 1, 1, 1);
    }
  }

  List<FocusSession> _sessionsForPeriod(List<FocusSession> sessions) {
    final start = _periodStart;
    final end = _periodEnd;
    final result = sessions.where((session) {
      final startedAt = session.startedAt.toLocal();
      return !startedAt.isBefore(start) && startedAt.isBefore(end);
    }).toList();
    result.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return result;
  }

  String _periodTitle() {
    final now = DateTime.now();
    switch (_granularity) {
      case _HistoryGranularity.week:
        final start = _periodStart;
        if (start == startOfFocusWeek(now)) return '\u672c\u5468';
        final end = start.add(const Duration(days: 6));
        return '${start.month}\u6708${start.day}\u65e5 - '
            '${end.month}\u6708${end.day}\u65e5';
      case _HistoryGranularity.month:
        if (_periodStart.year == now.year && _periodStart.month == now.month) {
          return '\u672c\u6708';
        }
        return '${_periodStart.year}\u5e74${_periodStart.month}\u6708';
      case _HistoryGranularity.year:
        if (_periodStart.year == now.year) return '\u672c\u5e74';
        return '${_periodStart.year}\u5e74';
    }
  }

  List<_HistoryDayGroup> _groupSessions(List<FocusSession> sessions) {
    final groups = <String, _HistoryDayGroup>{};
    for (final session in sessions) {
      final date = session.startedAt.toLocal();
      final key = '${date.year}-${date.month}-${date.day}';
      groups
          .putIfAbsent(
            key,
            () => _HistoryDayGroup(date: date, sessions: []),
          )
          .sessions
          .add(session);
    }
    final result = groups.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));
    for (final group in result) {
      group.sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    }
    return result;
  }
}

class _PeriodSelector extends StatelessWidget {
  const _PeriodSelector({
    required this.title,
    required this.onPrevious,
    required this.onNext,
    required this.onSelected,
  });

  final String title;
  final VoidCallback onPrevious;
  final VoidCallback onNext;
  final ValueChanged<_HistoryGranularity> onSelected;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onPrevious,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.chevron_left, size: 30),
        ),
        Expanded(
          child: Center(
            child: PopupMenuButton<_HistoryGranularity>(
              onSelected: onSelected,
              position: PopupMenuPosition.under,
              itemBuilder: (context) => const [
                PopupMenuItem(
                  value: _HistoryGranularity.week,
                  child: Text('\u5468'),
                ),
                PopupMenuItem(
                  value: _HistoryGranularity.month,
                  child: Text('\u6708'),
                ),
                PopupMenuItem(
                  value: _HistoryGranularity.year,
                  child: Text('\u5e74'),
                ),
              ],
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 18,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(width: 3),
                      const Icon(Icons.keyboard_arrow_down, size: 19),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        IconButton(
          onPressed: onNext,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.chevron_right, size: 30),
        ),
      ],
    );
  }
}

class _WeekSummary {
  _WeekSummary({required this.weekStart, required this.sessions})
      : daySeconds = List<int>.filled(7, 0);

  factory _WeekSummary.fromSessions(
    List<FocusSession> sessions,
    DateTime weekStart,
  ) {
    final summary = _WeekSummary(
      weekStart: weekStart,
      sessions: sessions,
    );
    for (final session in sessions) {
      final index =
          startOfLocalDay(session.startedAt).difference(weekStart).inDays;
      if (index >= 0 && index < 7) {
        summary.daySeconds[index] += session.actualDurationSeconds;
      }
    }
    return summary;
  }

  final DateTime weekStart;
  final List<FocusSession> sessions;
  final List<int> daySeconds;

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
          children: [
            Expanded(
              child: _WeekStat(
                value: formatFocusHoursMinutes(summary.totalSeconds),
                label: '\u4e13\u6ce8\u65f6\u957f',
              ),
            ),
            const SizedBox(width: 25),
            _WeekStat(
                value: '${summary.count}', label: '\u4e13\u6ce8\u6b21\u6570'),
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
                label: '\u5e73\u5747\u6bcf\u5929',
              ),
            ),
            Container(width: 1, height: 54, color: const Color(0xFFE4E4E4)),
            Expanded(
              child: _WeekStat(
                value: summary.count == 0
                    ? '\u6682\u65e0'
                    : '${_weekday(summary.longestDayIndex)} · '
                        '${formatFocusHoursMinutes(longestSeconds)}',
                label: summary.count == 0
                    ? '\u672c\u5468\u6682\u65e0\u8bb0\u5f55'
                    : '\u6700\u957f\u4e00\u5929',
              ),
            ),
          ],
        ),
      ],
    );
  }

  String _weekday(int index) => const [
        '\u5468\u4e00',
        '\u5468\u4e8c',
        '\u5468\u4e09',
        '\u5468\u56db',
        '\u5468\u4e94',
        '\u5468\u516d',
        '\u5468\u65e5',
      ][index];
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

  String _weekday(int weekday) => const [
        '\u4e00',
        '\u4e8c',
        '\u4e09',
        '\u56db',
        '\u4e94',
        '\u516d',
        '\u65e5',
      ][weekday - 1];
}

class _WeekStat extends StatelessWidget {
  const _WeekStat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
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
          textAlign: TextAlign.center,
          style: const TextStyle(color: Color(0xFF858585), fontSize: 16),
        ),
      ],
    );
  }
}

class _MonthOverview extends StatelessWidget {
  const _MonthOverview({
    required this.month,
    required this.sessions,
    required this.onDayTap,
  });

  final DateTime month;
  final List<FocusSession> sessions;
  final ValueChanged<DateTime> onDayTap;

  @override
  Widget build(BuildContext context) {
    final daySeconds = <int, int>{};
    for (final session in sessions) {
      final local = session.startedAt.toLocal();
      daySeconds[local.day] =
          (daySeconds[local.day] ?? 0) + session.actualDurationSeconds;
    }
    final maxSeconds = daySeconds.values.fold<int>(
      0,
      (max, value) => value > max ? value : max,
    );
    final daysInMonth = DateTime(month.year, month.month + 1, 0).day;
    final leadingEmpty = DateTime(month.year, month.month, 1).weekday - 1;
    final totalCells = ((leadingEmpty + daysInMonth + 6) ~/ 7) * 7;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _PeriodTotals(
          totalSeconds: sessions.fold(
            0,
            (total, session) => total + session.actualDurationSeconds,
          ),
          count: sessions.length,
        ),
        const SizedBox(height: 30),
        const Row(
          children: [
            _CalendarWeekday(label: '\u4e00'),
            _CalendarWeekday(label: '\u4e8c'),
            _CalendarWeekday(label: '\u4e09'),
            _CalendarWeekday(label: '\u56db'),
            _CalendarWeekday(label: '\u4e94'),
            _CalendarWeekday(label: '\u516d'),
            _CalendarWeekday(label: '\u65e5'),
          ],
        ),
        const SizedBox(height: 10),
        GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: totalCells,
          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: 7,
            crossAxisSpacing: 8,
            mainAxisSpacing: 8,
            childAspectRatio: 1,
          ),
          itemBuilder: (context, index) {
            final day = index - leadingEmpty + 1;
            if (day < 1 || day > daysInMonth) return const SizedBox.shrink();
            final date = DateTime(month.year, month.month, day);
            final seconds = daySeconds[day] ?? 0;
            return _HeatCell(
              label: '$day',
              seconds: seconds,
              maxSeconds: maxSeconds,
              onTap: () => onDayTap(date),
            );
          },
        ),
        const SizedBox(height: 18),
        const _HeatLegend(),
      ],
    );
  }
}

class _YearOverview extends StatelessWidget {
  const _YearOverview({
    required this.year,
    required this.sessions,
    required this.onMonthTap,
  });

  final int year;
  final List<FocusSession> sessions;
  final ValueChanged<DateTime> onMonthTap;

  @override
  Widget build(BuildContext context) {
    final buckets = List<List<int>>.generate(12, (_) => [0, 0, 0, 0]);
    for (final session in sessions) {
      final local = session.startedAt.toLocal();
      if (local.year != year) continue;
      final bucket = ((local.day - 1) ~/ 7).clamp(0, 3);
      buckets[local.month - 1][bucket] += session.actualDurationSeconds;
    }
    final maxSeconds = buckets
        .expand((monthBuckets) => monthBuckets)
        .fold<int>(0, (max, value) => value > max ? value : max);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        for (var row = 0; row < 4; row++) ...[
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var column = 0; column < 3; column++)
                Expanded(
                  child: Padding(
                    padding: EdgeInsets.only(right: column == 2 ? 0 : 8),
                    child: _YearMonthBlock(
                      seconds: buckets[row * 3 + column],
                      maxSeconds: maxSeconds,
                      onTap: () => onMonthTap(
                        DateTime(year, row * 3 + column + 1, 1),
                      ),
                    ),
                  ),
                ),
            ],
          ),
          if (row != 3) const SizedBox(height: 8),
        ],
        const SizedBox(height: 12),
        const _HeatLegend(),
      ],
    );
  }
}

class _PeriodTotals extends StatelessWidget {
  const _PeriodTotals({required this.totalSeconds, required this.count});

  final int totalSeconds;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _WeekStat(
            value: formatFocusHoursMinutes(totalSeconds),
            label: '\u4e13\u6ce8\u65f6\u957f',
          ),
        ),
        const SizedBox(width: 25),
        _WeekStat(value: '$count', label: '\u4e13\u6ce8\u6b21\u6570'),
      ],
    );
  }
}

class _CalendarWeekday extends StatelessWidget {
  const _CalendarWeekday({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: const TextStyle(color: Color(0xFF858585), fontSize: 14),
      ),
    );
  }
}

class _HeatCell extends StatelessWidget {
  const _HeatCell({
    required this.label,
    required this.seconds,
    required this.maxSeconds,
    required this.onTap,
  });

  final String label;
  final int seconds;
  final int maxSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final level = _heatLevel(seconds, maxSeconds);
    return InkWell(
      onTap: onTap,
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: _heatColor(level),
          borderRadius: BorderRadius.circular(3),
        ),
        child: Text(
          label,
          style: TextStyle(
            color: level >= 4 ? Colors.white : const Color(0xFF555555),
            fontSize: 14,
          ),
        ),
      ),
    );
  }
}

class _YearMonthBlock extends StatelessWidget {
  const _YearMonthBlock({
    required this.seconds,
    required this.maxSeconds,
    required this.onTap,
  });

  final List<int> seconds;
  final int maxSeconds;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Row(
        children: [
          for (var index = 0; index < 4; index++)
            Expanded(
              child: Padding(
                padding: EdgeInsets.only(right: index == 3 ? 0 : 3),
                child: AspectRatio(
                  aspectRatio: 1,
                  child: Container(
                    decoration: BoxDecoration(
                      color: _heatColor(
                        _heatLevel(seconds[index], maxSeconds),
                      ),
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _HeatLegend extends StatelessWidget {
  const _HeatLegend();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        const Text(
          '\u5c11',
          style: TextStyle(color: Color(0xFF858585), fontSize: 13),
        ),
        const SizedBox(width: 6),
        for (var level = 0; level <= 4; level++) ...[
          Container(
            width: 13,
            height: 13,
            decoration: BoxDecoration(
              color: _heatColor(level),
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          if (level != 4) const SizedBox(width: 3),
        ],
        const SizedBox(width: 6),
        const Text(
          '\u591a',
          style: TextStyle(color: Color(0xFF858585), fontSize: 13),
        ),
      ],
    );
  }
}

class _EmptyHistory extends StatelessWidget {
  const _EmptyHistory();

  @override
  Widget build(BuildContext context) {
    return const Text(
      '\u8fd9\u4e00\u65f6\u95f4\u6bb5\u8fd8\u6ca1\u6709\u4e13\u6ce8\u8bb0\u5f55',
      style: TextStyle(color: Color(0xFF858585), fontSize: 18),
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
                  '${group.sessions.length} \u6b21\u4e13\u6ce8 · '
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

DateTime _dateOnly(DateTime date) => DateTime(date.year, date.month, date.day);

int _heatLevel(int seconds, int maxSeconds) {
  if (seconds <= 0 || maxSeconds <= 0) return 0;
  final ratio = seconds / maxSeconds;
  if (ratio <= .25) return 1;
  if (ratio <= .5) return 2;
  if (ratio <= .75) return 3;
  return 4;
}

Color _heatColor(int level) {
  switch (level) {
    case 1:
      return const Color(0xFFE5E5E5);
    case 2:
      return const Color(0xFFBDBDBD);
    case 3:
      return const Color(0xFF777777);
    case 4:
      return const Color(0xFF111111);
    default:
      return const Color(0xFFF4F4F4);
  }
}
