import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/focus_session_provider.dart';
import '../../utils/focus_formatters.dart';
import '../../widgets/focus_session_entry.dart';
import 'record_detail_screen.dart';

class DayDetailScreen extends StatelessWidget {
  const DayDetailScreen({super.key, required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final inheritedProvider =
        Provider.of<FocusSessionProvider?>(context, listen: false);
    if (inheritedProvider != null) return _DayDetailContent(date: date);

    return ChangeNotifierProvider(
      create: (_) => FocusSessionProvider()..loadSessions(),
      child: _DayDetailContent(date: date),
    );
  }
}

class _DayDetailContent extends StatelessWidget {
  const _DayDetailContent({required this.date});

  final DateTime date;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusSessionProvider>();
    final sessions = provider.sessionsForDay(date);
    final totalSeconds = sessions.fold<int>(
      0,
      (total, session) => total + session.actualDurationSeconds,
    );

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: provider.isLoading
                  ? const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF111111),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(24, 12, 24, 36),
                      children: [
                        _HistoryDetailTopBar(
                          title: formatFocusDate(date),
                        ),
                        const SizedBox(height: 58),
                        Text(
                          formatFocusHoursMinutes(totalSeconds),
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 42,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '专注时长',
                          style: TextStyle(
                            color: Color(0xFF858585),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          '${sessions.length}',
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 36,
                            height: 1.05,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 8),
                        const Text(
                          '专注次数',
                          style: TextStyle(
                            color: Color(0xFF858585),
                            fontSize: 18,
                          ),
                        ),
                        const SizedBox(height: 45),
                        if (sessions.isEmpty)
                          const Text(
                            '这一天还没有专注记录',
                            style: TextStyle(
                              color: Color(0xFF858585),
                              fontSize: 18,
                            ),
                          )
                        else
                          for (final session in sessions)
                            FocusSessionEntry(
                              session: session,
                              onTap: () => Navigator.of(context).push(
                                MaterialPageRoute(
                                  builder: (_) => RecordDetailScreen(
                                    session: session,
                                  ),
                                ),
                              ),
                            ),
                      ],
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _HistoryDetailTopBar extends StatelessWidget {
  const _HistoryDetailTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Row(
        children: [
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            icon: const Icon(Icons.arrow_back, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              title,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 22,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
