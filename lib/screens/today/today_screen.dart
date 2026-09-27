import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/focus_provider.dart';
import '../../providers/task_provider.dart';
import '../focus/focus_screen.dart';
import '../history/history_screen.dart';
import '../../widgets/chrona_widgets.dart';

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key, this.taskProvider});

  final TaskProvider? taskProvider;

  @override
  Widget build(BuildContext context) {
    if (taskProvider != null) {
      return ChangeNotifierProvider.value(
        value: taskProvider!,
        child: const _TodayScreenContent(),
      );
    }

    return ChangeNotifierProvider(
      create: (_) => TaskProvider()..loadTasks(),
      child: const _TodayScreenContent(),
    );
  }
}

class _TodayScreenContent extends StatefulWidget {
  const _TodayScreenContent();

  @override
  State<_TodayScreenContent> createState() => _TodayScreenContentState();
}

class _TodayScreenContentState extends State<_TodayScreenContent> {
  int _selectedTab = 0;
  FocusProvider? _activeFocusProvider;

  @override
  void dispose() {
    _activeFocusProvider?.dispose();
    super.dispose();
  }

  void _openFocus(Task task) {
    final activeProvider = _activeFocusProvider;
    final canResume = activeProvider != null &&
        activeProvider.task.id == task.id &&
        (activeProvider.isRunning || activeProvider.isPaused);
    if (!canResume) {
      activeProvider?.dispose();
      _activeFocusProvider = FocusProvider(
        task: task,
        plannedDurationSeconds: task.durationSeconds,
      );
    }

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          task: task,
          durationSeconds: task.durationSeconds,
          focusProvider: _activeFocusProvider,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: _TodayTabContent(
                selectedTab: _selectedTab,
                onStartFocus: _openFocus,
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: _selectedTab,
              onTabSelected: (index) {
                if (index == 1) {
                  Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const HistoryScreen()));
                  return;
                }
                setState(() => _selectedTab = index);
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class _TodayTabContent extends StatelessWidget {
  const _TodayTabContent({
    required this.selectedTab,
    required this.onStartFocus,
  });

  final int selectedTab;
  final ValueChanged<Task> onStartFocus;

  @override
  Widget build(BuildContext context) {
    if (selectedTab != 0) {
      return _PlaceholderTab(title: selectedTab == 1 ? '记录' : '设置');
    }
    return _TodayHomeContent(onStartFocus: onStartFocus);
  }
}

class _TodayHomeContent extends StatelessWidget {
  const _TodayHomeContent({required this.onStartFocus});

  final ValueChanged<Task> onStartFocus;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    if (taskProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Color(0xFF111111),
        ),
      );
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const BrandHeader(),
                const SizedBox(height: 48),
                _TodaySummary(completedCount: taskProvider.completedCount),
                const SizedBox(height: 27),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                for (final task in taskProvider.tasks)
                  _TaskRow(
                    task: task,
                    onToggle: () => taskProvider.toggleTask(task),
                    onDelete: () => _confirmDelete(context, task),
                    onStart: task.completed ? null : () => onStartFocus(task),
                  ),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
              child:
                  _AddTaskButton(onPressed: () => _showAddTaskDialog(context))),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(28, 48, 24, 24),
          sliver: SliverToBoxAdapter(child: _BrandQuote()),
        ),
      ],
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final draft = await showDialog<_TaskDraft>(
      context: context,
      builder: (dialogContext) => const _AddTaskDialog(),
    );
    if (draft != null && context.mounted) {
      await context.read<TaskProvider>().addTask(
            title: draft.title,
            note: draft.note,
            durationSeconds: draft.durationSeconds,
          );
    }
  }

  Future<void> _confirmDelete(BuildContext context, Task task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: Text('删除「${task.title}」？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
            ),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      await context.read<TaskProvider>().deleteTask(task);
    }
  }
}

class _TodaySummary extends StatelessWidget {
  const _TodaySummary({required this.completedCount});

  final int completedCount;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('今天',
                  style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 38,
                      height: 1.05,
                      fontWeight: FontWeight.w600)),
              SizedBox(height: 13),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text('9 月 27 日 · 星期六',
                    style: TextStyle(
                        color: Color(0xFF8B8B8B),
                        fontSize: 19,
                        height: 1.1,
                        letterSpacing: 1.1)),
              ),
            ],
          ),
        ),
        _StatBlock(value: '$completedCount', label: '已完成'),
        Container(
            width: 1,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 17),
            color: const Color(0xFFE6E6E6)),
        const _StatBlock(value: '3.5', label: '专注时长 (h)'),
      ],
    );
  }
}

class _TaskDraft {
  const _TaskDraft({
    required this.title,
    required this.note,
    required this.durationSeconds,
  });

  final String title;
  final String note;
  final int durationSeconds;
}

class _AddTaskDialog extends StatefulWidget {
  const _AddTaskDialog();

  @override
  State<_AddTaskDialog> createState() => _AddTaskDialogState();
}

class _AddTaskDialogState extends State<_AddTaskDialog> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  String? _titleError;
  String? _durationError;
  Duration _duration = const Duration(minutes: 25);

  int get _durationSeconds => _duration.inSeconds;

  String get _durationLabel {
    final hours = _duration.inHours;
    final minutes = _duration.inMinutes.remainder(60);
    final seconds = _duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController();
    _noteController = TextEditingController();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      title: const Text('添加任务'),
      content: SizedBox(
        width: 320,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _titleController,
                autofocus: true,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: '标题',
                  hintText: '输入任务名称',
                  errorText: _titleError,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111)),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _noteController,
                maxLines: 2,
                textInputAction: TextInputAction.done,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  hintText: '补充一点说明',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111)),
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  const Text(
                    '\u4E13\u6CE8\u65F6\u957F',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  Text(
                    _durationLabel,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 22,
                      fontWeight: FontWeight.w500,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                height: 156,
                width: double.infinity,
                child: CupertinoTheme(
                  data: const CupertinoThemeData(
                    brightness: Brightness.light,
                    primaryColor: Color(0xFF111111),
                  ),
                  child: CupertinoTimerPicker(
                    mode: CupertinoTimerPickerMode.hms,
                    initialTimerDuration: _duration,
                    onTimerDurationChanged: (duration) => setState(() {
                      _duration = duration;
                      _durationError = null;
                    }),
                  ),
                ),
              ),
              if (_durationError != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _durationError!,
                    style: const TextStyle(
                      color: Color(0xFFB3261E),
                      fontSize: 12,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            final title = _titleController.text.trim();
            if (title.isEmpty) {
              setState(() => _titleError = '标题不能为空');
              return;
            }
            if (_durationSeconds == 0) {
              setState(() => _durationError =
                  '\u4E13\u6CE8\u65F6\u957F\u4E0D\u80FD\u4E3A 0');
              return;
            }
            Navigator.of(context).pop(
              _TaskDraft(
                title: title,
                note: _noteController.text,
                durationSeconds: _durationSeconds,
              ),
            );
          },
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFF111111),
            foregroundColor: Colors.white,
          ),
          child: const Text('添加'),
        ),
      ],
    );
  }
}

class _StatBlock extends StatelessWidget {
  const _StatBlock({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Text(value,
            style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 30,
                height: 1,
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 10),
        Text(label,
            style: const TextStyle(
                color: Color(0xFF8B8B8B), fontSize: 15, height: 1)),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onDelete,
    required this.onStart,
  });

  final Task task;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final textDecoration = task.completed ? TextDecoration.lineThrough : null;
    final contentColor =
        task.completed ? const Color(0xFF6F6F6F) : const Color(0xFF111111);
    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
          border:
              Border(bottom: BorderSide(color: Color(0xFFE9E9E9), width: 1))),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CompletionButton(completed: task.completed, onPressed: onToggle),
          const SizedBox(width: 17),
          Expanded(
            child: Opacity(
              opacity: task.completed ? 0.65 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(task.title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: contentColor,
                          fontSize: 21,
                          height: 1.25,
                          fontWeight: FontWeight.w500,
                          decoration: textDecoration,
                          decorationThickness: 1.5)),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(Icons.notes_outlined,
                          size: 18, color: Color(0xFF8A8A8A)),
                      const SizedBox(width: 7),
                      Flexible(
                          child: Text(task.note ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  color: Color(0xFF8A8A8A),
                                  fontSize: 16,
                                  height: 1.15))),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Opacity(
              opacity: task.completed ? 0.65 : 1,
              child: Text(_formatTaskDuration(task.durationSeconds),
                  style: const TextStyle(
                      color: Color(0xFF858585), fontSize: 16, height: 1.1))),
          const SizedBox(width: 17),
          IconButton(
            onPressed: onDelete,
            icon: const Icon(Icons.delete_outline, size: 20),
            color: const Color(0xFF8A8A8A),
            padding: EdgeInsets.zero,
            visualDensity: VisualDensity.compact,
            constraints: const BoxConstraints.tightFor(width: 32, height: 32),
            tooltip: '删除任务',
          ),
          _StartButton(onPressed: onStart),
        ],
      ),
    );
  }
}

// ignore: unused_element
String _legacyMockFocusDuration(Task task) {
  const fiftyMinuteTasks = {'写 RagForge', '健身', '看技术分享'};
  return fiftyMinuteTasks.contains(task.title) ? '50 min' : '25 min';
}

String _formatTaskDuration(int seconds) {
  final hours = seconds ~/ 3600;
  final minutes = (seconds % 3600) ~/ 60;
  final remainingSeconds = seconds % 60;
  if (hours > 0) {
    return '$hours h ${minutes.toString().padLeft(2, '0')} min';
  }
  if (remainingSeconds > 0) {
    return '$minutes min ${remainingSeconds.toString().padLeft(2, '0')} sec';
  }
  return '$minutes min';
}

class _CompletionButton extends StatelessWidget {
  const _CompletionButton({required this.completed, required this.onPressed});

  final bool completed;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: SizedBox(
        width: 42,
        height: 42,
        child: Center(
          child: Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: completed ? const Color(0xFF111111) : Colors.transparent,
                border: completed
                    ? null
                    : Border.all(color: const Color(0xFF777777), width: 1.5)),
            child: completed
                ? const Icon(Icons.check, color: Colors.white, size: 19)
                : null,
          ),
        ),
      ),
    );
  }
}

class _StartButton extends StatelessWidget {
  const _StartButton({required this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    return InkWell(
      onTap: onPressed,
      customBorder: const CircleBorder(),
      child: Container(
        width: 42,
        height: 42,
        decoration: const BoxDecoration(
            shape: BoxShape.circle, color: Color(0xFFF0F0F0)),
        child: Icon(Icons.play_arrow_rounded,
            size: 23,
            color: enabled ? const Color(0xFF111111) : const Color(0xFFC9C9C9)),
      ),
    );
  }
}

class _AddTaskButton extends StatelessWidget {
  const _AddTaskButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      width: double.infinity,
      child: TextButton.icon(
        onPressed: onPressed,
        style: TextButton.styleFrom(
            foregroundColor: const Color(0xFF111111),
            backgroundColor: const Color(0xFFF6F6F6),
            shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10))),
        icon: const Icon(Icons.add, size: 27),
        label: const Text('添加任务',
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500)),
      ),
    );
  }
}

class _BrandQuote extends StatelessWidget {
  const _BrandQuote();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(width: 4, height: 112, color: const Color(0xFFE2E2E2)),
        const SizedBox(width: 18),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('不是时间不够用，\n而是我们没有好好拾起它。',
                style: TextStyle(
                    color: Color(0xFF888888), fontSize: 17, height: 1.7)),
            SizedBox(height: 5),
            Text('— 拾年',
                style: TextStyle(
                    color: Color(0xFF888888), fontSize: 16, height: 1.3)),
          ],
        ),
      ],
    );
  }
}

class _PlaceholderTab extends StatelessWidget {
  const _PlaceholderTab({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const BrandHeader(),
          const SizedBox(height: 64),
          Text(title,
              style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 36,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 14),
          const Text('这里将在后续版本开放。',
              style: TextStyle(color: Color(0xFF888888), fontSize: 17)),
        ],
      ),
    );
  }
}
