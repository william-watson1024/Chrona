import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../widgets/chrona_widgets.dart';
import '../history/history_screen.dart';
import 'focus_note_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({super.key, required this.task});

  final Task task;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  bool _isPaused = false;

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
                  children: [
                    _FocusTopBar(onBack: () => Navigator.of(context).pop()),
                    const SizedBox(height: 48),
                    Text(
                      widget.task.title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 31,
                        height: 1.2,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 13),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.notes_outlined,
                            size: 21, color: Color(0xFF858585)),
                        const SizedBox(width: 8),
                        Text(
                          widget.task.note ?? '',
                          style: const TextStyle(
                              color: Color(0xFF858585),
                              fontSize: 20,
                              height: 1.15),
                        ),
                      ],
                    ),
                    const SizedBox(height: 64),
                    const _FocusProgress(),
                    const SizedBox(height: 58),
                    ConstrainedBox(
                      constraints: const BoxConstraints(maxWidth: 520),
                      child: PrimaryButton(
                        label: _isPaused ? '继续' : '暂停',
                        onPressed: () => setState(() => _isPaused = !_isPaused),
                      ),
                    ),
                    const SizedBox(height: 24),
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => FocusNoteScreen(task: widget.task)),
                      ),
                      style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF111111)),
                      child: const Text('结束专注',
                          style: TextStyle(
                              fontSize: 21, fontWeight: FontWeight.w500)),
                    ),
                    const SizedBox(height: 48),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.info_outline,
                            size: 22, color: Color(0xFF8B8B8B)),
                        SizedBox(width: 10),
                        Text('时间结束后将通过震动提醒',
                            style: TextStyle(
                                color: Color(0xFF8B8B8B), fontSize: 17)),
                      ],
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
}

class _FocusTopBar extends StatelessWidget {
  const _FocusTopBar({required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        IconButton(
          onPressed: onBack,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.arrow_back, size: 29),
          tooltip: '返回',
        ),
        IconButton(
          onPressed: () {},
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.settings_outlined, size: 24),
          tooltip: '设置',
        ),
      ],
    );
  }
}

class _FocusProgress extends StatelessWidget {
  const _FocusProgress();

  @override
  Widget build(BuildContext context) {
    return const SizedBox(
      width: 306,
      height: 306,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 306,
            height: 306,
            child: CircularProgressIndicator(
              value: 0.68,
              strokeWidth: 9,
              backgroundColor: Color(0xFFF0F0F0),
              valueColor: AlwaysStoppedAnimation<Color>(Color(0xFF111111)),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('24:37',
                  style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 70,
                      height: 1,
                      fontWeight: FontWeight.w300,
                      letterSpacing: 1)),
              SizedBox(height: 16),
              Text('专注中',
                  style: TextStyle(
                      color: Color(0xFF8B8B8B), fontSize: 22, height: 1.1)),
            ],
          ),
        ],
      ),
    );
  }
}
