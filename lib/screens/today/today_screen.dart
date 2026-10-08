import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/task.dart';
import '../../models/journal_entry.dart';
import '../../providers/focus_provider.dart';
import '../../providers/focus_session_provider.dart';
import '../../providers/journal_provider.dart';
import '../../providers/task_provider.dart';
import '../../utils/focus_formatters.dart';
import '../focus/focus_screen.dart';
import '../history/history_screen.dart';
import '../settings/settings_screen.dart';
import 'task_detail_screen.dart';
import '../../widgets/chrona_date_picker.dart';
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
  late final PageController _diaryPageController;
  DateTime _selectedDate = startOfLocalDay(DateTime.now());
  DateTime _lastObservedToday = startOfLocalDay(DateTime.now());
  FocusProvider? _activeFocusProvider;
  bool _restoreAttempted = false;
  bool _isOpeningDatePicker = false;
  int? _pendingSyncedPage;
  bool? _pendingSyncedPageIsDiary;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _pageAnchor);
    _diaryPageController = PageController(initialPage: _pageAnchor);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(_restoreActiveFocus());
    });
  }

  @override
  void dispose() {
    final provider = _activeFocusProvider;
    provider?.removeListener(_handleActiveFocusChanged);
    provider?.dispose();
    WidgetsBinding.instance.removeObserver(this);
    _pageController.dispose();
    _diaryPageController.dispose();
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      _syncPageController(_pageController, page);
      _syncPageController(_diaryPageController, page);
    });
  }

  void _handlePageChanged(int page, bool fromDiary) {
    final date = _dateForPage(page);
    _selectedDate = date;

    // A mirrored jump emits its own onPageChanged callback. Consume that
    // callback instead of bouncing a second jump back to the source PageView.
    if (_pendingSyncedPage == page && _pendingSyncedPageIsDiary == fromDiary) {
      _pendingSyncedPage = null;
      _pendingSyncedPageIsDiary = null;
      return;
    }

    final otherController = fromDiary ? _pageController : _diaryPageController;
    if (!otherController.hasClients || otherController.page?.round() == page) {
      return;
    }

    _pendingSyncedPage = page;
    _pendingSyncedPageIsDiary = !fromDiary;
    otherController.jumpToPage(page);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_pendingSyncedPage != page ||
          _pendingSyncedPageIsDiary != !fromDiary) {
        return;
      }
      _pendingSyncedPage = null;
      _pendingSyncedPageIsDiary = null;
    });
  }

  void _syncPageController(PageController controller, int page) {
    if (controller.hasClients && controller.page?.round() != page) {
      controller.jumpToPage(page);
    }
  }

  Future<void> _openDatePicker() async {
    if (_isOpeningDatePicker) return;
    _isOpeningDatePicker = true;
    try {
      final picked = await showDialog<DateTime>(
        context: context,
        barrierDismissible: false,
        builder: (_) => ChronaDatePickerDialog(initialDate: _selectedDate),
      );
      if (picked != null && mounted) _selectDate(picked);
    } finally {
      _isOpeningDatePicker = false;
    }
  }

  Future<void> _restoreActiveFocus() async {
    if (_restoreAttempted) return;
    _restoreAttempted = true;

    // The timer snapshot includes a task fallback, so restoring does not
    // depend on the task list finishing first. Loading here still lets the
    // normal home screen settle before the restored session is presented.
    await context.read<TaskProvider>().loadTasks();
    if (!mounted) return;

    final restored = await FocusProvider.restore();
    if (!mounted || restored == null) return;

    _activeFocusProvider = restored;
    context.read<TaskProvider>().setFocusedTask(
          restored.mode == FocusMode.focus && restored.isRunning
              ? restored.task.id
              : null,
        );
    restored.addListener(_handleActiveFocusChanged);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _activeFocusProvider != restored) return;
      if (ModalRoute.of(context)?.isCurrent != true) return;
      Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => FocusScreen(
            task: restored.task,
            taskProvider: context.read<TaskProvider>(),
            durationSeconds: restored.plannedDurationSeconds,
            mode: restored.mode,
            focusProvider: restored,
          ),
        ),
      );
    });
  }

  void _openFocus(Task task) {
    unawaited(_openFocusAsync(task));
  }

  Future<void> _openFocusAsync(Task task) async {
    var activeProvider = _activeFocusProvider;
    var shouldRestorePersistedFocus = activeProvider != null &&
        !activeProvider.isRunning &&
        !activeProvider.isPaused;
    if (activeProvider != null &&
        activeProvider.task.id != task.id &&
        activeProvider.isPaused) {
      activeProvider.removeListener(_handleActiveFocusChanged);
      activeProvider.discardPaused();
      activeProvider.dispose();
      _activeFocusProvider = null;
      activeProvider = null;
    } else if (activeProvider != null &&
        activeProvider.task.id != task.id &&
        activeProvider.isRunning) {
      return;
    }

    if (activeProvider != null &&
        !activeProvider.isRunning &&
        !activeProvider.isPaused) {
      activeProvider.removeListener(_handleActiveFocusChanged);
      activeProvider.dispose();
      _activeFocusProvider = null;
      activeProvider = null;
    }

    if (activeProvider == null && shouldRestorePersistedFocus) {
      final restored = await FocusProvider.restore();
      if (!mounted) {
        restored?.dispose();
        return;
      }
      if (restored != null && (restored.isRunning || restored.isPaused)) {
        _activeFocusProvider = restored;
        restored.addListener(_handleActiveFocusChanged);
        activeProvider = restored;
        if (restored.task.id != task.id && restored.isRunning) return;
      } else {
        restored?.dispose();
      }
      shouldRestorePersistedFocus = false;
    }

    if (activeProvider != null &&
        activeProvider.task.id != task.id &&
        activeProvider.isPaused) {
      activeProvider.removeListener(_handleActiveFocusChanged);
      activeProvider.discardPaused();
      activeProvider.dispose();
      _activeFocusProvider = null;
      activeProvider = null;
    }
    if (activeProvider != null &&
        activeProvider.task.id != task.id &&
        activeProvider.isRunning) {
      return;
    }

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
    final currentFocus = _activeFocusProvider!;
    context.read<TaskProvider>().setFocusedTask(
          currentFocus.mode == FocusMode.focus && currentFocus.isRunning
              ? currentFocus.task.id
              : null,
        );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          task: task,
          taskProvider: context.read<TaskProvider>(),
          durationSeconds: task.durationSeconds,
          focusProvider: _activeFocusProvider,
        ),
      ),
    );
  }

  void _handleActiveFocusChanged() {
    final activeProvider = _activeFocusProvider;
    if (!mounted || activeProvider == null) return;

    if (!activeProvider.isFinished) return;
    if (ModalRoute.of(context)?.isCurrent != true) return;

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => FocusScreen(
          task: activeProvider.task,
          taskProvider: context.read<TaskProvider>(),
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
                selectedDate: _selectedDate,
                onStartFocus: _openFocus,
                pageController: _pageController,
                diaryPageController: _diaryPageController,
                onPageChanged: _handlePageChanged,
                dateForPage: _dateForPage,
                onOpenDatePicker: _openDatePicker,
                onOpenSettings: () => Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const SettingsScreen()),
                ),
                onTabChanged: (tab) => setState(() => _selectedTab = tab),
                onGoToLastYear: () =>
                    _selectDate(_sameDayLastYear(_selectedDate)),
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 0,
              onTabSelected: (index) {
                if (index == 0) {
                  _selectDate(DateTime.now());
                  if (_selectedTab != 0) setState(() => _selectedTab = 0);
                  return;
                }
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
    required this.selectedDate,
    required this.onStartFocus,
    required this.pageController,
    required this.diaryPageController,
    required this.onPageChanged,
    required this.dateForPage,
    required this.onOpenDatePicker,
    required this.onOpenSettings,
    required this.onTabChanged,
    required this.onGoToLastYear,
  });

  final int selectedTab;
  final DateTime selectedDate;
  final ValueChanged<Task> onStartFocus;
  final PageController pageController;
  final PageController diaryPageController;
  final void Function(int page, bool fromDiary) onPageChanged;
  final DateTime Function(int page) dateForPage;
  final VoidCallback onOpenDatePicker;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onGoToLastYear;

  @override
  Widget build(BuildContext context) {
    return IndexedStack(
      index: selectedTab,
      children: [
        PageView.builder(
          controller: pageController,
          onPageChanged: (page) => onPageChanged(page, false),
          itemBuilder: (context, page) {
            final date = dateForPage(page);
            return _TodayHomeContent(
              key: ValueKey(JournalEntry.dateKey(date)),
              selectedDate: date,
              onStartFocus: onStartFocus,
              onOpenDatePicker: onOpenDatePicker,
              onOpenSettings: onOpenSettings,
              onTabChanged: onTabChanged,
            );
          },
        ),
        PageView.builder(
          controller: diaryPageController,
          onPageChanged: (page) => onPageChanged(page, true),
          itemBuilder: (context, page) {
            final date = dateForPage(page);
            return _TodayDiaryContent(
              key: ValueKey(JournalEntry.dateKey(date)),
              selectedDate: date,
              onOpenDatePicker: onOpenDatePicker,
              onOpenSettings: onOpenSettings,
              onTabChanged: onTabChanged,
              onGoToLastYear: onGoToLastYear,
            );
          },
        ),
      ],
    );
  }
}

class _TodayHomeContent extends StatelessWidget {
  const _TodayHomeContent({
    super.key,
    required this.selectedDate,
    required this.onStartFocus,
    required this.onOpenDatePicker,
    required this.onOpenSettings,
    required this.onTabChanged,
  });

  final DateTime selectedDate;
  final ValueChanged<Task> onStartFocus;
  final VoidCallback onOpenDatePicker;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onTabChanged;

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
                _TodayHeader(
                  selectedDate: selectedDate,
                  completedCount:
                      taskProvider.completedCountForDate(selectedDate),
                  focusDurationHours:
                      focusDurationSeconds / Duration.secondsPerHour,
                  onTap: onOpenDatePicker,
                  selectedTab: 0,
                  onTabChanged: onTabChanged,
                  onOpenSettings: onOpenSettings,
                ),
                const SizedBox(height: 27),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverReorderableList(
            key: ValueKey(JournalEntry.dateKey(selectedDate)),
            itemCount: tasks.length,
            findChildIndexCallback: (key) {
              if (key is! ValueKey<int>) return null;
              final index = tasks.indexWhere(
                (task) => (task.id ?? task.createdAt) == key.value,
              );
              return index == -1 ? null : index;
            },
            onReorderItem: (oldIndex, newIndex) {
              taskProvider.reorderTasksForDate(
                selectedDate,
                oldIndex,
                newIndex,
              );
            },
            proxyDecorator: (child, index, animation) => Material(
              color: Colors.white,
              elevation: 0,
              child: child,
            ),
            itemBuilder: (context, index) {
              final task = tasks[index];
              return ReorderableDelayedDragStartListener(
                key: ValueKey(task.id ?? task.createdAt),
                index: index,
                child: _TaskRow(
                  task: task,
                  isFocused: task.id != null &&
                      !task.completed &&
                      task.id == taskProvider.focusedTaskId,
                  focusAttentionVersion: taskProvider.focusAttentionVersion,
                  onTap: () {
                    if (task.id != taskProvider.focusedTaskId) {
                      taskProvider.pulseFocusedTask();
                    }
                    _openTask(context, task);
                  },
                  onToggle: () => taskProvider.toggleTask(task),
                  onDelete: () => _confirmDelete(context, task),
                  onStart: task.completed ? null : () => onStartFocus(task),
                ),
              );
            },
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

  void _openTask(BuildContext context, Task task) {
    final taskProvider = context.read<TaskProvider>();
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => TaskDetailScreen(
          task: task,
          taskProvider: taskProvider,
        ),
      ),
    );
  }
}

class _TodayHeader extends StatelessWidget {
  const _TodayHeader({
    required this.selectedDate,
    required this.completedCount,
    required this.focusDurationHours,
    required this.onTap,
    required this.selectedTab,
    required this.onTabChanged,
    required this.onOpenSettings,
  });

  final DateTime selectedDate;
  final int completedCount;
  final double focusDurationHours;
  final VoidCallback onTap;
  final int selectedTab;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        BrandHeader(onSettingsPressed: onOpenSettings),
        const SizedBox(height: 48),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            GestureDetector(
              onTap: onTap,
              child: Text(
                _dateStatusTitle(selectedDate),
                style: const TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 38,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const Spacer(),
            _TodayTabSwitcher(
              selectedTab: selectedTab,
              onChanged: onTabChanged,
            ),
          ],
        ),
        const SizedBox(height: 13),
        _TodaySummaryLine(
          selectedDate: selectedDate,
          completedCount: completedCount,
          focusDurationHours: focusDurationHours,
          onTap: onTap,
        ),
      ],
    );
  }
}

class _TodayTabSwitcher extends StatelessWidget {
  const _TodayTabSwitcher({required this.selectedTab, required this.onChanged});

  final int selectedTab;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _TodayTab(
          label: '\u4e13\u6ce8',
          selected: selectedTab == 0,
          onTap: () => onChanged(0),
        ),
        const SizedBox(width: 24),
        _TodayTab(
          label: '\u65e5\u8bb0',
          selected: selectedTab == 1,
          onTap: () => onChanged(1),
        ),
      ],
    );
  }
}

class _TodayTab extends StatelessWidget {
  const _TodayTab({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF111111) : const Color(0xFF858585);
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 7),
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              bottom: BorderSide(
                color: selected ? const Color(0xFF111111) : Colors.transparent,
                width: 2,
              ),
            ),
          ),
          child: Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 17,
              fontWeight: selected ? FontWeight.w500 : FontWeight.w400,
            ),
          ),
        ),
      ),
    );
  }
}

class _TodaySummaryLine extends StatelessWidget {
  const _TodaySummaryLine({
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
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            formatFocusDate(selectedDate),
            style: const TextStyle(
              color: Color(0xFF858585),
              fontSize: 16,
              height: 1.1,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            '$completedCount \u5df2\u5b8c\u6210\u00b7'
            '${focusDurationHours.toStringAsFixed(2)}h \u4e13\u6ce8\u65f6\u957f',
            style: const TextStyle(
              color: Color(0xFF858585),
              fontSize: 16,
              height: 1.1,
            ),
          ),
        ],
      ),
    );
  }
}

class _TodayDiaryContent extends StatefulWidget {
  const _TodayDiaryContent({
    super.key,
    required this.selectedDate,
    required this.onOpenDatePicker,
    required this.onOpenSettings,
    required this.onTabChanged,
    required this.onGoToLastYear,
  });

  final DateTime selectedDate;
  final VoidCallback onOpenDatePicker;
  final VoidCallback onOpenSettings;
  final ValueChanged<int> onTabChanged;
  final VoidCallback onGoToLastYear;

  @override
  State<_TodayDiaryContent> createState() => _TodayDiaryContentState();
}

class _TodayDiaryContentState extends State<_TodayDiaryContent> {
  late final TextEditingController _questionController;
  late final TextEditingController _diaryController;
  late final JournalProvider _journalProvider;
  String _questionText = JournalEntry.defaultQuestionText;
  String? _appliedDate;
  bool _hasLocalEdits = false;
  bool _applyingEntry = false;
  bool _isChangingQuestion = false;

  @override
  void initState() {
    super.initState();
    _journalProvider = JournalProvider()..loadJournal(widget.selectedDate);
    _journalProvider.addListener(_onJournalChanged);
    _questionController = TextEditingController();
    _diaryController = TextEditingController();
    _questionController.addListener(_onTextChanged);
    _diaryController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _journalProvider
      ..removeListener(_onJournalChanged)
      ..dispose();
    _questionController
      ..removeListener(_onTextChanged)
      ..dispose();
    _diaryController
      ..removeListener(_onTextChanged)
      ..dispose();
    super.dispose();
  }

  void _onTextChanged() {
    if (!_applyingEntry) _hasLocalEdits = true;
    setState(() {});
  }

  void _onJournalChanged() {
    if (mounted) setState(() {});
  }

  Future<void> _save() async {
    final provider = _journalProvider;
    try {
      await provider.saveJournal(
        date: widget.selectedDate,
        questionText: _questionText,
        questionAnswer: _questionController.text,
        content: _diaryController.text,
      );
      if (!mounted) return;
      _hasLocalEdits = false;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u5df2\u4fdd\u5b58')),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                '\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5')),
      );
    }
  }

  Future<void> _randomizeQuestion() async {
    if (_isChangingQuestion) return;
    if (_questionController.text.trim().isNotEmpty) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('\u6362\u4e00\u4e2a\u95ee\u9898'),
          content: const Text(
            '\u66f4\u6362\u95ee\u9898\u4e0d\u4f1a\u6e05\u7a7a\u5f53\u524d\u56de\u7b54\uff0c\u662f\u5426\u7ee7\u7eed\uff1f',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(false),
              child: const Text('\u53d6\u6d88'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(true),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
              ),
              child: const Text('\u7ee7\u7eed'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }

    setState(() => _isChangingQuestion = true);
    try {
      await _journalProvider.replaceQuestionWithRandom();
      if (!mounted) return;
      setState(() {
        _questionText = _journalProvider.questionText;
        _hasLocalEdits = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                '\u6362\u9898\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5')),
      );
    } finally {
      if (mounted) setState(() => _isChangingQuestion = false);
    }
  }

  Future<void> _restoreDefaultQuestion() async {
    if (_isChangingQuestion) return;
    setState(() => _isChangingQuestion = true);
    try {
      await _journalProvider.restoreDefaultQuestion();
      if (!mounted) return;
      setState(() {
        _questionText = _journalProvider.questionText;
        _hasLocalEdits = false;
      });
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text(
                '\u6062\u590d\u9ed8\u8ba4\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5')),
      );
    } finally {
      if (mounted) setState(() => _isChangingQuestion = false);
    }
  }

  Future<void> _changeQuestion() async {
    var draftQuestion = _questionText;
    final value = await showDialog<String>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.white,
        surfaceTintColor: Colors.transparent,
        title: const Text('\u4fee\u6539\u4eca\u65e5\u95ee\u9898'),
        content: TextFormField(
          initialValue: _questionText,
          autofocus: true,
          maxLines: 4,
          maxLength: 200,
          onChanged: (value) => draftQuestion = value,
          decoration: const InputDecoration(
            hintText: '\u8f93\u5165\u4eca\u5929\u7684\u95ee\u9898',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('\u53d6\u6d88'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(draftQuestion),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF111111),
              foregroundColor: Colors.white,
            ),
            child: const Text('\u786e\u5b9a'),
          ),
        ],
      ),
    );
    if (value == null || !mounted) return;
    final normalized = JournalEntry.normalizeQuestionText(value);
    setState(() {
      _questionText = normalized;
      _hasLocalEdits = true;
    });
    try {
      await _journalProvider.updateQuestion(normalized);
      if (!mounted) return;
      _hasLocalEdits = false;
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('问题保存失败，请稍后重试')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final taskProvider = context.watch<TaskProvider>();
    final sessionProvider = context.watch<FocusSessionProvider>();
    final journalProvider = _journalProvider;
    final loadedDate = journalProvider.loadedDate;
    if (!journalProvider.isLoading &&
        loadedDate != null &&
        _appliedDate != loadedDate) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || _appliedDate == loadedDate) return;
        _appliedDate = loadedDate;
        if (_hasLocalEdits) return;
        final entry = _journalProvider.entry;
        _applyingEntry = true;
        _questionText = _journalProvider.questionText;
        _questionController.text = entry?.questionAnswer ?? '';
        _diaryController.text = entry?.content ?? '';
        _applyingEntry = false;
        setState(() {});
      });
    }
    if (taskProvider.isLoading) {
      return const Center(
        child: CircularProgressIndicator(
          strokeWidth: 1.5,
          color: Color(0xFF111111),
        ),
      );
    }

    final focusDurationSeconds =
        sessionProvider.focusDurationSecondsForDay(widget.selectedDate);
    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _TodayHeader(
              selectedDate: widget.selectedDate,
              completedCount: taskProvider.completedCountForDate(
                widget.selectedDate,
              ),
              focusDurationHours:
                  focusDurationSeconds / Duration.secondsPerHour,
              onTap: widget.onOpenDatePicker,
              selectedTab: 1,
              onTabChanged: widget.onTabChanged,
              onOpenSettings: widget.onOpenSettings,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 27, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                _DiaryCard(
                  icon: Icons.wb_sunny_outlined,
                  title: '\u6bcf\u65e5\u4e00\u95ee',
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      TextButton(
                        onPressed:
                            _isChangingQuestion ? null : _randomizeQuestion,
                        style: TextButton.styleFrom(
                          foregroundColor: const Color(0xFF555555),
                          padding: const EdgeInsets.symmetric(horizontal: 6),
                          minimumSize: Size.zero,
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                        child: const Text('\u6362\u4e00\u4e2a'),
                      ),
                      if (_journalProvider.dailyQuestion?.isModified == true)
                        TextButton(
                          onPressed: _isChangingQuestion
                              ? null
                              : _restoreDefaultQuestion,
                          style: TextButton.styleFrom(
                            foregroundColor: const Color(0xFF555555),
                            padding: const EdgeInsets.symmetric(horizontal: 6),
                            minimumSize: Size.zero,
                            tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                          ),
                          child: const Text('\u6062\u590d\u9ed8\u8ba4'),
                        ),
                      IconButton(
                        onPressed: _isChangingQuestion ? null : _changeQuestion,
                        padding: EdgeInsets.zero,
                        visualDensity: VisualDensity.compact,
                        icon: const Icon(Icons.edit_outlined, size: 20),
                        tooltip: '\u4fee\u6539\u95ee\u9898',
                      ),
                    ],
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u201c$_questionText\u201d',
                        style: const TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 18,
                          height: 1.55,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 16),
                      _DiaryInput(
                        controller: _questionController,
                        hintText:
                            '\u5199\u4e0b\u4f60\u7684\u56de\u7b54\u2026\u2026',
                        maxLength: 500,
                        maxLines: 4,
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                _DiaryCard(
                  icon: Icons.menu_book_outlined,
                  title: '\u4eca\u65e5\u65e5\u8bb0',
                  child: _DiaryInput(
                    controller: _diaryController,
                    hintText:
                        '\u4eca\u5929\u53d1\u751f\u4e86\u4ec0\u4e48\u2026\u2026\n\u53ef\u4ee5\u8bb0\u5f55\u4f60\u7684\u60f3\u6cd5\u3001\u60c5\u7eea\u3001\u6536\u83b7\uff0c\u6216\u4efb\u4f55\u60f3\u8bf4\u7684\u3002',
                    maxLength: 1000,
                    maxLines: 5,
                  ),
                ),
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: widget.onGoToLastYear,
                    style: TextButton.styleFrom(
                      foregroundColor: const Color(0xFF555555),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                    ),
                    icon: const Icon(Icons.history_outlined, size: 18),
                    label: const Text('\u53bb\u5e74\u4eca\u65e5'),
                  ),
                ),
                const SizedBox(height: 14),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: FilledButton(
                    onPressed: journalProvider.isSaving ? null : _save,
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: const Text(
                      '\u4fdd\u5b58',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _DiaryCard extends StatelessWidget {
  const _DiaryCard({
    required this.icon,
    required this.title,
    required this.child,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xFFF8F8F8),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF111111)),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Color(0xFF111111),
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 15),
          child,
        ],
      ),
    );
  }
}

class _DiaryInput extends StatelessWidget {
  const _DiaryInput({
    required this.controller,
    required this.hintText,
    required this.maxLength,
    required this.maxLines,
  });

  final TextEditingController controller;
  final String hintText;
  final int maxLength;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(13, 10, 13, 7),
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border.all(color: const Color(0xFFE1E1E1)),
        borderRadius: BorderRadius.circular(9),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          TextField(
            controller: controller,
            maxLength: maxLength,
            maxLines: maxLines,
            minLines: maxLines,
            decoration: InputDecoration(
              hintText: hintText,
              hintStyle: const TextStyle(
                color: Color(0xFF9A9A9A),
                fontSize: 15,
                height: 1.45,
              ),
              border: InputBorder.none,
              isDense: true,
              contentPadding: EdgeInsets.zero,
              counterText: '',
            ),
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 15,
              height: 1.45,
            ),
          ),
          Text(
            '${controller.text.length}/$maxLength',
            style: const TextStyle(color: Color(0xFF858585), fontSize: 13),
          ),
        ],
      ),
    );
  }
}

DateTime _sameDayLastYear(DateTime date) {
  final year = date.year - 1;
  final lastDayOfMonth = DateTime(year, date.month + 1, 0).day;
  final day = date.day > lastDayOfMonth ? lastDayOfMonth : date.day;
  return DateTime(year, date.month, day);
}

String _dateStatusTitle(DateTime date) {
  final selected = startOfLocalDay(date);
  final today = startOfLocalDay(DateTime.now());
  if (selected == today) return '今朝';
  return selected.isBefore(today) ? '往昔' : '来生';
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
  String? _durationError;
  Duration _duration = const Duration(minutes: 25);

  int get _durationSeconds => _duration.inSeconds;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: '\u9ED8\u8BA4\u4EFB\u52A1');
    _titleController.selection = TextSelection(
      baseOffset: 0,
      extentOffset: _titleController.text.length,
    );
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
                decoration: const InputDecoration(
                  labelText: '标题',
                  hintText: '输入任务名称',
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: UnderlineInputBorder(
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
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Text(
                    '\u4E13\u6CE8\u65F6\u957F',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: SizedBox(
                      height: 96,
                      child: LoopingDurationPicker(
                        initialDuration: _duration,
                        onDurationChanged: (duration) => setState(() {
                          _duration = duration;
                          _durationError = null;
                        }),
                      ),
                    ),
                  ),
                ],
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
            final title = _titleController.text.trim().isEmpty
                ? '\u9ED8\u8BA4\u4EFB\u52A1'
                : _titleController.text.trim();
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

class _TaskRow extends StatefulWidget {
  const _TaskRow({
    required this.task,
    required this.isFocused,
    required this.focusAttentionVersion,
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onStart,
  });

  final Task task;
  final bool isFocused;
  final int focusAttentionVersion;
  final VoidCallback onTap;
  final VoidCallback onToggle;
  final VoidCallback onDelete;
  final VoidCallback? onStart;

  @override
  State<_TaskRow> createState() => _TaskRowState();
}

class _TaskRowState extends State<_TaskRow>
    with SingleTickerProviderStateMixin {
  late final AnimationController _attentionController;
  late final Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _attentionController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 460),
    );
    _scaleAnimation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween<double>(begin: 1, end: 1.035)
            .chain(CurveTween(curve: Curves.easeOut)),
        weight: 35,
      ),
      TweenSequenceItem(
        tween: Tween<double>(begin: 1.035, end: 1)
            .chain(CurveTween(curve: Curves.easeInOut)),
        weight: 65,
      ),
    ]).animate(_attentionController);
  }

  @override
  void didUpdateWidget(covariant _TaskRow oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isFocused &&
        widget.focusAttentionVersion != oldWidget.focusAttentionVersion) {
      _attentionController.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _attentionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final task = widget.task;
    final textDecoration = task.completed ? TextDecoration.lineThrough : null;
    final contentColor =
        task.completed ? const Color(0xFF6F6F6F) : const Color(0xFF111111);
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        constraints: const BoxConstraints(minHeight: 94),
        padding: const EdgeInsets.symmetric(vertical: 16),
        decoration: const BoxDecoration(
            border:
                Border(bottom: BorderSide(color: Color(0xFFE9E9E9), width: 1))),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _CompletionButton(
                completed: task.completed, onPressed: widget.onToggle),
            const SizedBox(width: 17),
            Expanded(
              child: GestureDetector(
                onTap: widget.onTap,
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
                              child: Text(
                                  formatFocusDuration(task.durationSeconds),
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
            ),
            const SizedBox(width: 17),
            IconButton(
              onPressed: widget.onDelete,
              icon: const Icon(Icons.delete_outline, size: 20),
              color: const Color(0xFF8A8A8A),
              padding: EdgeInsets.zero,
              visualDensity: VisualDensity.compact,
              constraints: const BoxConstraints.tightFor(width: 32, height: 32),
              tooltip: '删除任务',
            ),
            _StartButton(
                onPressed: widget.onStart, isFocused: widget.isFocused),
          ],
        ),
      ),
    );
  }
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
  const _StartButton({required this.onPressed, required this.isFocused});

  final VoidCallback? onPressed;
  final bool isFocused;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null;
    if (isFocused) {
      return InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(18),
        child: Container(
          height: 36,
          padding: const EdgeInsets.symmetric(horizontal: 10),
          decoration: BoxDecoration(
            color: const Color(0xFF111111),
            borderRadius: BorderRadius.circular(18),
          ),
          child: const Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.graphic_eq_rounded, size: 17, color: Colors.white),
              SizedBox(width: 4),
              Text(
                '正在专注',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      );
    }
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
