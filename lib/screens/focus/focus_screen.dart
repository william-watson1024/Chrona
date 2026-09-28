import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/focus_provider.dart';
import '../../services/notification_service.dart';
import '../../widgets/chrona_widgets.dart';
import '../history/history_screen.dart';
import 'focus_note_screen.dart';

class FocusScreen extends StatefulWidget {
  const FocusScreen({
    super.key,
    required this.task,
    this.durationSeconds = FocusTimerDurations.pomodoro,
    this.mode = FocusMode.focus,
    this.nextFocusDurationSeconds,
    this.now,
    this.focusProvider,
  });

  final Task task;
  final int durationSeconds;
  final FocusMode mode;
  final int? nextFocusDurationSeconds;
  final DateTime Function()? now;
  final FocusProvider? focusProvider;

  @override
  State<FocusScreen> createState() => _FocusScreenState();
}

class _FocusScreenState extends State<FocusScreen> {
  late final FocusProvider _focusProvider;
  late final bool _ownsFocusProvider;
  bool _hasOpenedNote = false;

  @override
  void initState() {
    super.initState();
    _ownsFocusProvider = widget.focusProvider == null;
    _focusProvider = widget.focusProvider ??
        FocusProvider(
          task: widget.task,
          plannedDurationSeconds: widget.durationSeconds,
          mode: widget.mode,
          now: widget.now,
        );
    _focusProvider.addListener(_handleFocusChanged);
    if (_focusProvider.status == FocusTimerStatus.idle) {
      _focusProvider.start();
    }
    if (_focusProvider.status == FocusTimerStatus.finished ||
        _focusProvider.status == FocusTimerStatus.cancelled) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _handleFocusChanged();
      });
    }
  }

  @override
  void dispose() {
    _focusProvider.removeListener(_handleFocusChanged);
    if (_ownsFocusProvider) _focusProvider.dispose();
    super.dispose();
  }

  void _handleFocusChanged() {
    final status = _focusProvider.status;
    if (widget.mode == FocusMode.rest ||
        _hasOpenedNote ||
        (status != FocusTimerStatus.finished &&
            status != FocusTimerStatus.cancelled)) {
      return;
    }

    _hasOpenedNote = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FocusNoteScreen(
            session: _focusProvider.sessionResult,
          ),
        ),
      );
    });
  }

  void _startNextFocus() {
    final nextDuration =
        widget.nextFocusDurationSeconds ?? FocusTimerDurations.pomodoro;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          task: widget.task,
          durationSeconds: nextDuration,
          mode: FocusMode.focus,
        ),
      ),
    );
  }

  void _skipBreak() {
    _focusProvider.skipBreak();
  }

  Future<void> _confirmEnd() async {
    final shouldEnd = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('提前结束本轮专注？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('继续专注'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
            ),
            child: const Text('结束'),
          ),
        ],
      ),
    );
    if (shouldEnd == true && mounted) _focusProvider.cancel();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: _focusProvider,
      child: Consumer<FocusProvider>(
        builder: (context, provider, child) {
          final isBreak = provider.mode == FocusMode.rest;
          final isBreakReady =
              isBreak && provider.status == FocusTimerStatus.finished;
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
                          _FocusTopBar(
                            onBack: () => Navigator.of(context).pop(),
                          ),
                          const SizedBox(height: 48),
                          Text(
                            isBreak ? '休息一下' : provider.task.title,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF111111),
                              fontSize: 31,
                              height: 1.2,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 13),
                          if (!isBreak &&
                              provider.task.note?.isNotEmpty == true)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.notes_outlined,
                                  size: 21,
                                  color: Color(0xFF858585),
                                ),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    provider.task.note!,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      color: Color(0xFF858585),
                                      fontSize: 20,
                                      height: 1.15,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          const SizedBox(height: 64),
                          if (isBreak) ...[
                            const Text(
                              '短休息',
                              style: TextStyle(
                                color: Color(0xFF858585),
                                fontSize: 20,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          GestureDetector(
                            behavior: HitTestBehavior.opaque,
                            onTap: provider.toggleTimerDisplay,
                            child: _FocusProgress(
                              remainingSeconds: provider.remainingSeconds,
                              displaySeconds: provider.displaySeconds,
                              plannedDurationSeconds:
                                  provider.plannedDurationSeconds,
                              status: provider.status,
                            ),
                          ),
                          const SizedBox(height: 58),
                          if (isBreakReady) ...[
                            const Text(
                              '准备开始下一轮',
                              style: TextStyle(
                                color: Color(0xFF858585),
                                fontSize: 20,
                                height: 1.1,
                              ),
                            ),
                            const SizedBox(height: 24),
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: PrimaryButton(
                                label: '开始专注',
                                onPressed: _startNextFocus,
                              ),
                            ),
                          ] else ...[
                            ConstrainedBox(
                              constraints: const BoxConstraints(maxWidth: 520),
                              child: PrimaryButton(
                                label: provider.isPaused ? '继续' : '暂停',
                                onPressed: provider.isPaused
                                    ? provider.resume
                                    : provider.pause,
                              ),
                            ),
                            const SizedBox(height: 24),
                          ],
                          if (isBreak && !isBreakReady)
                            TextButton(
                              onPressed: _skipBreak,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF111111),
                              ),
                              child: const Text('跳过休息'),
                            ),
                          if (!isBreak &&
                              provider.status == FocusTimerStatus.finished)
                            TextButton(
                              onPressed: () =>
                                  NotificationService.instance.cancelFocusEnd(),
                              child: const Text('停止提醒'),
                            ),
                          if (!isBreak &&
                              provider.status == FocusTimerStatus.finished)
                            const SizedBox(height: 8),
                          if (!isBreak)
                            TextButton(
                              onPressed: _confirmEnd,
                              style: TextButton.styleFrom(
                                foregroundColor: const Color(0xFF111111),
                              ),
                              child: const Text(
                                '结束专注',
                                style: TextStyle(
                                  fontSize: 21,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          const SizedBox(height: 48),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(
                                Icons.info_outline,
                                size: 22,
                                color: Color(0xFF8B8B8B),
                              ),
                              const SizedBox(width: 10),
                              Text(
                                isBreak ? '休息结束后将响铃并震动' : '时间结束后将通过震动提醒',
                                style: const TextStyle(
                                  color: Color(0xFF8B8B8B),
                                  fontSize: 17,
                                ),
                              ),
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
                          MaterialPageRoute(
                            builder: (_) => const HistoryScreen(),
                          ),
                        );
                      }
                    },
                  ),
                  SizedBox(height: MediaQuery.paddingOf(context).bottom),
                ],
              ),
            ),
          );
        },
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
  const _FocusProgress({
    required this.remainingSeconds,
    required this.displaySeconds,
    required this.plannedDurationSeconds,
    required this.status,
  });

  final int remainingSeconds;
  final int displaySeconds;
  final int plannedDurationSeconds;
  final FocusTimerStatus status;

  @override
  Widget build(BuildContext context) {
    final progress = plannedDurationSeconds == 0
        ? 1.0
        : (1 - remainingSeconds / plannedDurationSeconds).clamp(0.0, 1.0);
    final statusLabel = switch (status) {
      FocusTimerStatus.paused => '已暂停',
      FocusTimerStatus.finished => '已完成',
      FocusTimerStatus.cancelled => '已结束',
      _ => '专注中',
    };

    return SizedBox(
      width: 306,
      height: 306,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: 306,
            height: 306,
            child: CircularProgressIndicator(
              value: progress,
              strokeWidth: 9,
              backgroundColor: const Color(0xFFF0F0F0),
              valueColor: const AlwaysStoppedAnimation<Color>(
                Color(0xFF111111),
              ),
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                _formatRemaining(displaySeconds),
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 70,
                  height: 1,
                  fontWeight: FontWeight.w300,
                  letterSpacing: 1,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                statusLabel,
                style: const TextStyle(
                  color: Color(0xFF8B8B8B),
                  fontSize: 22,
                  height: 1.1,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatRemaining(int seconds) {
    final minutes = seconds ~/ 60;
    final remaining = seconds % 60;
    return '${minutes.toString().padLeft(2, '0')}:${remaining.toString().padLeft(2, '0')}';
  }
}
