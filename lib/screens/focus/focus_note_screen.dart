import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../providers/focus_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/chrona_widgets.dart';
import '../history/history_screen.dart';

class FocusNoteScreen extends StatefulWidget {
  const FocusNoteScreen({super.key, required this.session});

  final FocusSessionResult session;

  @override
  State<FocusNoteScreen> createState() => _FocusNoteScreenState();
}

class _FocusNoteScreenState extends State<FocusNoteScreen> {
  late final TextEditingController _noteController;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: ChronaMockData.focusNote);
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _NoteTopBar(onBack: () => Navigator.of(context).pop()),
                    const SizedBox(height: 72),
                    Text(
                      widget.session.status == FocusTimerStatus.cancelled
                          ? '本轮专注结束'
                          : '本轮专注完成',
                      style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 34,
                          height: 1.1,
                          fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 43),
                    Text(
                      widget.session.task.title,
                      style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${_formatTime(widget.session.startedAt)} - '
                      '${_formatTime(widget.session.endedAt)} · '
                      '${_formatDuration(widget.session.actualDurationSeconds)}',
                      style: const TextStyle(
                          color: Color(0xFF8B8B8B), fontSize: 20, height: 1.1),
                    ),
                    if (widget.session.status ==
                        FocusTimerStatus.cancelled) ...[
                      const SizedBox(height: 8),
                      const Text(
                        '提前结束',
                        style: TextStyle(
                            color: Color(0xFF8B8B8B),
                            fontSize: 16,
                            height: 1.1),
                      ),
                    ],
                    const SizedBox(height: 79),
                    const Text(
                      '这段时间做了什么？',
                      style: TextStyle(
                          color: Color(0xFF111111), fontSize: 22, height: 1.2),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      controller: _noteController,
                      minLines: 8,
                      maxLines: 12,
                      textAlignVertical: TextAlignVertical.top,
                      style: const TextStyle(
                          color: Color(0xFF888888), fontSize: 20, height: 1.45),
                      decoration: InputDecoration(
                        filled: false,
                        contentPadding:
                            const EdgeInsets.fromLTRB(36, 29, 24, 24),
                        enabledBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFFE0E0E0)),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10),
                          borderSide:
                              const BorderSide(color: Color(0xFF111111)),
                        ),
                      ),
                    ),
                    const SizedBox(height: 38),
                    TextButton(
                      onPressed: () =>
                          NotificationService.instance.cancelFocusEnd(),
                      style: TextButton.styleFrom(
                        foregroundColor: const Color(0xFF111111),
                      ),
                      child: const Text('停止提醒'),
                    ),
                    const SizedBox(height: 12),
                    PrimaryButton(
                      label: '保存',
                      onPressed: () => Navigator.of(context).pushAndRemoveUntil(
                        MaterialPageRoute(
                            builder: (_) => const HistoryScreen()),
                        (route) => route.isFirst,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 0,
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.of(context).pop();
                } else if (index == 1) {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()));
                }
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  String _formatTime(DateTime time) {
    return '${time.hour.toString().padLeft(2, '0')}:'
        '${time.minute.toString().padLeft(2, '0')}';
  }

  String _formatDuration(int seconds) {
    final minutes = seconds ~/ 60;
    if (minutes > 0) return '$minutes min';
    return '$seconds sec';
  }
}

class _NoteTopBar extends StatelessWidget {
  const _NoteTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 40,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Align(
            alignment: Alignment.centerLeft,
            child: IconButton(
              onPressed: onBack,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints.tightFor(width: 40, height: 40),
              icon: const Icon(Icons.arrow_back, size: 29),
              tooltip: '返回',
            ),
          ),
          const Text('本轮记录',
              style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 24,
                  fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }
}
