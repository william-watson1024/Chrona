import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_provider.dart';
import '../../providers/focus_settings_provider.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/task_provider.dart';
import '../../services/notification_service.dart';
import '../../utils/focus_formatters.dart';
import '../../widgets/chrona_widgets.dart';
import '../history/history_screen.dart';
import 'focus_screen.dart';

class FocusNoteScreen extends StatefulWidget {
  const FocusNoteScreen({
    super.key,
    required this.session,
    this.savedSession,
  });

  final FocusSessionResult session;
  final FocusSession? savedSession;

  @override
  State<FocusNoteScreen> createState() => _FocusNoteScreenState();
}

class _FocusNoteScreenState extends State<FocusNoteScreen> {
  late final TextEditingController _noteController;
  late final TextEditingController _taskTitleController;
  late final FocusSessionProvider _sessionProvider;
  late final bool _ownsSessionProvider;
  bool _isSaving = false;
  String? _saveError;

  bool get _isCompleted =>
      widget.session.status == FocusTimerStatus.finished;

  void _returnFromNote() {
    final navigator = Navigator.of(context);
    if (_isCompleted) {
      navigator.popUntil((route) => route.isFirst);
    } else {
      navigator.pop();
    }
  }

  void _handleSystemBack(bool didPop) {
    if (!didPop && _isCompleted) _returnFromNote();
  }

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController();
    _taskTitleController =
        TextEditingController(text: widget.session.task.title);
    final inheritedProvider =
        Provider.of<FocusSessionProvider?>(context, listen: false);
    _ownsSessionProvider = inheritedProvider == null;
    _sessionProvider = inheritedProvider ?? FocusSessionProvider();
  }

  @override
  void dispose() {
    _noteController.dispose();
    _taskTitleController.dispose();
    if (_ownsSessionProvider) _sessionProvider.dispose();
    super.dispose();
  }

  Future<void> _saveSession() async {
    if (_isSaving) return;
    final taskTitle = _taskTitleController.text.trim();
    if (taskTitle.isEmpty) {
      setState(() => _saveError = '任务名称不能为空');
      return;
    }
    setState(() {
      _isSaving = true;
      _saveError = null;
    });

    final updatedTask = widget.session.task.copyWith(title: taskTitle);
    final taskProvider = Provider.of<TaskProvider?>(context, listen: false);
    final settingsProvider =
        Provider.of<FocusSettingsProvider?>(context, listen: false);

    final session = FocusSession(
      taskId: widget.session.task.id,
      taskTitleSnapshot: taskTitle,
      startedAt: widget.session.startedAt,
      endedAt: widget.session.endedAt,
      plannedDurationSeconds: widget.session.plannedDurationSeconds,
      actualDurationSeconds: widget.session.actualDurationSeconds,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      status: widget.session.status == FocusTimerStatus.cancelled
          ? FocusSessionStatus.cancelled
          : FocusSessionStatus.completed,
      createdAt: DateTime.now(),
    );

    try {
      final saved = widget.savedSession != null
          ? await _sessionProvider.updateSessionDetails(
              widget.savedSession!,
              taskTitleSnapshot: taskTitle,
              note: session.note,
            )
          : await _sessionProvider.saveSessionIfAbsent(session);
      if (!mounted) return;
      if (saved == null) {
        setState(() {
          _isSaving = false;
          _saveError = '保存失败，请重试';
        });
        return;
      }
      await FocusProvider.clearPersistedState();
      if (taskProvider != null) {
        await taskProvider.updateTask(updatedTask);
      }
      if (!mounted) return;
      if (widget.session.status == FocusTimerStatus.finished) {
        final breakDuration = settingsProvider?.breakDurationSeconds ??
            FocusSettingsProvider.defaultBreakDurationSeconds;
        final nextFocusDuration = widget.session.task.durationSeconds;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(
            builder: (_) => FocusScreen(
              task: updatedTask,
              durationSeconds: breakDuration,
              mode: FocusMode.rest,
              nextFocusDurationSeconds: nextFocusDuration,
            ),
          ),
          (route) => route.isFirst,
        );
      } else {
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute(builder: (_) => const HistoryScreen()),
          (route) => route.isFirst,
        );
      }
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _saveError = '保存失败，请重试';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_isCompleted,
      onPopInvoked: _handleSystemBack,
      child: Scaffold(
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
                    _NoteTopBar(onBack: _returnFromNote),
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
                    TextField(
                      controller: _taskTitleController,
                      style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 30,
                          height: 1.15,
                          fontWeight: FontWeight.w500),
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.zero,
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      '${formatFocusTime(widget.session.startedAt)} - '
                      '${formatFocusTime(widget.session.endedAt)} · '
                      '${formatFocusDuration(widget.session.actualDurationSeconds)}',
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
                    if (_saveError != null) ...[
                      Text(
                        _saveError!,
                        style: const TextStyle(
                          color: Color(0xFFB3261E),
                          fontSize: 14,
                        ),
                      ),
                      const SizedBox(height: 12),
                    ],
                    PrimaryButton(
                      label: '保存',
                      onPressed: _isSaving ? () {} : _saveSession,
                    ),
                  ],
                ),
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 0,
              onTabSelected: (index) {
                if (index == 0) {
                  _returnFromNote();
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
      ),
    );
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
