import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../providers/focus_provider.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/focus_formatters.dart';
import '../focus/focus_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
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

class _TodayScreenContentState extends State<_TodayScreenContent>
    with WidgetsBindingObserver {
  static const int _pageAnchor = 20000;
  static final DateTime _anchorDate = DateTime.utc(
    DateTime.now().year,
    DateTime.now().month,
    DateTime.now().day,
  );

  int _selectedTab = 0;
  late final PageController _pageController;
  DateTime _selectedDate = startOfLocalDay(DateTime.now());
  DateTime _lastObservedToday = startOfLocalDay(DateTime.now());
  FocusProvider? _activeFocusProvider;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _pageAnchor);
  }

  @override
  void dispose() {
    final provider = _activeFocusProvider;
    provider?.removeListener(_handleActiveFocusChanged);
    provider?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    final today = startOfLocalDay(DateTime.now());
    final wasBrowsingToday = isSameLocalDay(_selectedDate, _lastObservedToday);
    _lastObservedToday = today;
    if (wasBrowsingToday) _selectDate(today);
  }

  DateTime _dateForPage(int page) {
    final utcDate = _anchorDate.add(
      Duration(days: page - _pageAnchor),
    );
    return DateTime(utcDate.year, utcDate.month, utcDate.day);
  }

  int _pageForDate(DateTime date) {
    final utcDate = DateTime.utc(date.year, date.month, date.day);
    return _pageAnchor + utcDate.difference(_anchorDate).inDays;
  }

  void _selectDate(DateTime date) {
    final normalized = startOfLocalDay(date);
    final page = _pageForDate(normalized);
    if (!isSameLocalDay(_selectedDate, normalized)) {
      setState(() => _selectedDate = normalized);
    }
    if (_pageController.hasClients && _pageController.page?.round() != page) {
      _pageController.animateToPage(
        page,
        duration: const Duration(milliseconds: 220),
        curve: Curves.easeOut,
      );
    }
  }

  void _handlePageChanged(int page) {
    final date = _dateForPage(page);
    if (!isSameLocalDay(_selectedDate, date)) {
      setState(() => _selectedDate = date);
    }
  }

  Future<void> _openDatePicker() async {
    final picked = await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _CompactDatePickerDialog(initialDate: _selectedDate),
    );
    if (picked != null && mounted) _selectDate(picked);
  }

  void _openFocus(Task task) {
    final activeProvider = _activeFocusProvider;
    final canResume = activeProvider != null &&
        activeProvider.task.id == task.id &&
        (activeProvider.isRunning || activeProvider.isPaused);
    if (!canResume) {
      activeProvider?.removeListener(_handleActiveFocusChanged);
      activeProvider?.dispose();
      _activeFocusProvider = FocusProvider(
        task: task,
        plannedDurationSeconds: task.durationSeconds,
      );
      _activeFocusProvider!.addListener(_handleActiveFocusChanged);
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

  void _handleActiveFocusChanged() {
    final activeProvider = _activeFocusProvider;
    if (!mounted || activeProvider == null || !activeProvider.isFinished) {
      return;
    }
    if (ModalRoute.of(context)?.isCurrent != true) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          task: activeProvider.task,
          durationSeconds: activeProvider.plannedDurationSeconds,
          focusProvider: activeProvider,
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
                pageController: _pageController,
                onPageChanged: _handlePageChanged,
                dateForPage: _dateForPage,
                onOpenDatePicker: _openDatePicker,
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
                if (index == 2) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const SettingsScreen()),
                  );
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
    required this.pageController,
    required this.onPageChanged,
    required this.dateForPage,
    required this.onOpenDatePicker,
  });

  final int selectedTab;
  final ValueChanged<Task> onStartFocus;
  final PageController pageController;
  final ValueChanged<int> onPageChanged;
  final DateTime Function(int page) dateForPage;
  final VoidCallback onOpenDatePicker;

  @override
  Widget build(BuildContext context) {
    if (selectedTab != 0) {
      return _PlaceholderTab(title: selectedTab == 1 ? '记录' : '设置');
    }
    return PageView.builder(
      controller: pageController,
      itemCount: 40001,
      onPageChanged: onPageChanged,
      itemBuilder: (context, page) {
        return _TodayHomeContent(
          selectedDate: dateForPage(page),
          onStartFocus: onStartFocus,
          onOpenDatePicker: onOpenDatePicker,
        );
      },
    );
  }
}

class _TodayHomeContent extends StatelessWidget {
  const _TodayHomeContent({
    required this.selectedDate,
    required this.onStartFocus,
    required this.onOpenDatePicker,
  });

  final DateTime selectedDate;
  final ValueChanged<Task> onStartFocus;
  final VoidCallback onOpenDatePicker;

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final focusSessionProvider = context.watch<FocusSessionProvider>();
    if (taskProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Color(0xFF111111),
        ),
      );
    }

    final tasks = taskProvider.tasksForDate(selectedDate);
    final focusDurationSeconds =
        focusSessionProvider.focusDurationSecondsForDay(selectedDate);

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
                _TodaySummary(
                  selectedDate: selectedDate,
                  completedCount:
                      taskProvider.completedCountForDate(selectedDate),
                  focusDurationHours:
                      focusDurationSeconds / Duration.secondsPerHour,
                  onTap: onOpenDatePicker,
                ),
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
                for (final task in tasks)
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
            planDate: selectedDate,
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
  const _TodaySummary({
    required this.selectedDate,
    required this.completedCount,
    required this.focusDurationHours,
    required this.onTap,
  });

  final DateTime selectedDate;
  final int completedCount;
  final double focusDurationHours;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Expanded(
          child: GestureDetector(
            onTap: onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_dateStatusTitle(selectedDate),
                    style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w600)),
                const SizedBox(height: 13),
                FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(formatFocusDate(selectedDate),
                      style: const TextStyle(
                          color: Color(0xFF8B8B8B),
                          fontSize: 15,
                          height: 1.1,
                          letterSpacing: 0)),
                ),
              ],
            ),
          ),
        ),
        _StatBlock(value: '$completedCount', label: '已完成'),
        Container(
            width: 1,
            height: 48,
            margin: const EdgeInsets.symmetric(horizontal: 17),
            color: const Color(0xFFE6E6E6)),
        _StatBlock(
          value: focusDurationHours.toStringAsFixed(2),
          label: '专注时长 (h)',
        ),
      ],
    );
  }
}

class _CompactDatePickerDialog extends StatefulWidget {
  const _CompactDatePickerDialog({required this.initialDate});

  final DateTime initialDate;

  @override
  State<_CompactDatePickerDialog> createState() =>
      _CompactDatePickerDialogState();
}

class _CompactDatePickerDialogState extends State<_CompactDatePickerDialog> {
  static final DateTime _firstDate = DateTime(2000);
  static final DateTime _lastDate = DateTime(2100, 12, 31);

  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late DateTime _selectedDate;
  bool _inputMode = false;

  @override
  void initState() {
    super.initState();
    _selectedDate = startOfLocalDay(widget.initialDate);
  }

  void _selectInputDate(DateTime value) {
    setState(() => _selectedDate = startOfLocalDay(value));
  }

  void _returnToToday() {
    Navigator.of(context).pop(startOfLocalDay(DateTime.now()));
  }

  void _confirm() {
    if (_inputMode && !(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    _formKey.currentState?.save();
    Navigator.of(context).pop(_selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    const colorScheme = ColorScheme.light(
      primary: Color(0xFF111111),
      onPrimary: Colors.white,
      surface: Colors.white,
      onSurface: Color(0xFF111111),
    );

    return Theme(
      data: Theme.of(context).copyWith(
        colorScheme: colorScheme,
        datePickerTheme: const DatePickerThemeData(
          headerBackgroundColor: Colors.white,
          headerForegroundColor: Color(0xFF111111),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.all(Radius.circular(4)),
          ),
        ),
      ),
      child: Dialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(4)),
        ),
        child: SizedBox(
          width: 360,
          child: Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          formatFocusDate(_selectedDate),
                          style: const TextStyle(
                            color: Color(0xFF111111),
                            fontSize: 20,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: _inputMode ? '日历' : '输入日期',
                        onPressed: () => setState(
                          () => _inputMode = !_inputMode,
                        ),
                        icon: Icon(
                          _inputMode
                              ? Icons.calendar_today_outlined
                              : Icons.edit_outlined,
                          color: const Color(0xFF111111),
                        ),
                      ),
                    ],
                  ),
                ),
                if (_inputMode)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 16, 24, 20),
                    child: Form(
                      key: _formKey,
                      child: InputDatePickerFormField(
                        initialDate: _selectedDate,
                        firstDate: _firstDate,
                        lastDate: _lastDate,
                        autofocus: true,
                        onDateSubmitted: _selectInputDate,
                        onDateSaved: _selectInputDate,
                      ),
                    ),
                  )
                else
                  CalendarDatePicker(
                    initialDate: _selectedDate,
                    firstDate: _firstDate,
                    lastDate: _lastDate,
                    currentDate: DateTime.now(),
                    onDateChanged: _selectInputDate,
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(8, 0, 8, 4),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.end,
                    children: [
                      TextButton(
                        onPressed: _returnToToday,
                        child: const Text('回到今朝'),
                      ),
                      TextButton(
                        onPressed: _confirm,
                        child: const Text('转赴其时'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

String _dateStatusTitle(DateTime date) {
  final selected = startOfLocalDay(date);
  final today = startOfLocalDay(DateTime.now());
  if (selected == today) return '今朝';
  return selected.isBefore(today) ? '往事' : '来日';
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
                      const Icon(Icons.schedule_outlined,
                          size: 18, color: Color(0xFF8A8A8A)),
                      const SizedBox(width: 7),
                      Flexible(
                          child: Text(_formatTaskDuration(task.durationSeconds),
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

String _formatTaskDuration(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ 3600;
  final minutes = (safeSeconds % 3600) ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  if (hours > 0) {
    final result = StringBuffer('${hours}h');
    if (minutes > 0) result.write('${minutes}m');
    if (remainingSeconds > 0) result.write('${remainingSeconds}s');
    return result.toString();
  }
  if (minutes > 0) {
    final result = StringBuffer('${minutes}m');
    if (remainingSeconds > 0) result.write('${remainingSeconds}s');
    return result.toString();
  }
  return remainingSeconds > 0 ? '${remainingSeconds}s' : '';
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
