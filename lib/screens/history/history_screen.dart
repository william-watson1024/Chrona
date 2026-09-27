import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_session_provider.dart';
import '../../utils/focus_formatters.dart';
import '../../widgets/chrona_widgets.dart';

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
                  return ListView(
                    physics: const BouncingScrollPhysics(),
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    children: [
                      const BrandHeader(),
                      const SizedBox(height: 67),
                      const Text(
                        '记录',
                        style: TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 38,
                            height: 1.05,
                            fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 64),
                      if (groups.isEmpty)
                        const Padding(
                          padding: EdgeInsets.only(top: 30),
                          child: Text(
                            '还没有专注记录',
                            style: TextStyle(
                                color: Color(0xFF858585), fontSize: 18),
                          ),
                        )
                      else
                        for (var index = 0; index < groups.length; index++) ...[
                          _HistoryGroup(group: groups[index]),
                          if (index != groups.length - 1)
                            const SizedBox(height: 65),
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

class _HistoryDayGroup {
  _HistoryDayGroup({required this.date, required this.sessions});

  final DateTime date;
  final List<FocusSession> sessions;
}

class _HistoryGroup extends StatelessWidget {
  const _HistoryGroup({required this.group});

  final _HistoryDayGroup group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          _dayLabel(group.date),
          style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 13),
        Text(
          _dateLabel(group.date),
          style: const TextStyle(
              color: Color(0xFF8B8B8B), fontSize: 20, height: 1.1),
        ),
        const SizedBox(height: 33),
        for (final session in group.sessions) _HistoryEntry(session: session),
      ],
    );
  }

  String _dayLabel(DateTime date) {
    final today = DateTime.now();
    final day = DateTime(date.year, date.month, date.day);
    final todayOnly = DateTime(today.year, today.month, today.day);
    if (day == todayOnly) return '今天';
    if (day == todayOnly.subtract(const Duration(days: 1))) return '昨天';
    return '${date.month}月${date.day}日';
  }

  String _dateLabel(DateTime date) {
    const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
    return '${date.month}月${date.day}日 · 星期${weekdays[date.weekday - 1]}';
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final note = session.note?.isNotEmpty == true ? session.note! : '未填写记录';
    final duration = formatFocusDuration(session.actualDurationSeconds);
    final durationLabel = session.status == FocusSessionStatus.cancelled
        ? '提前结束 · $duration'
        : duration;

    return Container(
      padding: const EdgeInsets.only(bottom: 25, top: 2),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            child: Text(
              '${formatFocusTime(session.startedAt)} — '
              '${formatFocusTime(session.endedAt)}',
              maxLines: 1,
              softWrap: false,
              style: const TextStyle(
                  color: Color(0xFF858585), fontSize: 18, height: 1.25),
            ),
          ),
          Container(
            width: 1,
            height: 82,
            margin: const EdgeInsets.only(right: 24),
            color: const Color(0xFFE1E1E1),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  session.taskTitleSnapshot,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 7),
                Text(
                  note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF858585), fontSize: 17, height: 1.3),
                ),
                const SizedBox(height: 7),
                Text(
                  durationLabel,
                  style: const TextStyle(
                      color: Color(0xFF858585), fontSize: 15, height: 1.1),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
