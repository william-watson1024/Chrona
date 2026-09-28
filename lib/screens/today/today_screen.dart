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

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _pageController = PageController(initialPage: _pageAnchor);
    _diaryPageController = PageController(initialPage: _pageAnchor);
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

  void _handlePageChanged(int page) {
    final date = _dateForPage(page);
    if (!isSameLocalDay(_selectedDate, date)) {
      setState(() => _selectedDate = date);
    }
    _syncPageController(_pageController, page);
    _syncPageController(_diaryPageController, page);
  }

  void _syncPageController(PageController controller, int page) {
    if (controller.hasClients && controller.page?.round() != page) {
      controller.jumpToPage(page);
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
  final ValueChanged<int> onPageChanged;
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
          itemCount: 40001,
          onPageChanged: onPageChanged,
          itemBuilder: (context, page) {
            return _TodayHomeContent(
              selectedDate: dateForPage(page),
              onStartFocus: onStartFocus,
              onOpenDatePicker: onOpenDatePicker,
              onOpenSettings: onOpenSettings,
              onTabChanged: onTabChanged,
            );
          },
        ),
        PageView.builder(
          controller: diaryPageController,
          itemCount: 40001,
          onPageChanged: onPageChanged,
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
          sliver: SliverToBoxAdapter(
            child: ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: false,
              itemCount: tasks.length,
              onReorderItem: (oldIndex, newIndex) {
                taskProvider.reorderTasksForDate(
                  selectedDate,
                  oldIndex,
                  newIndex,
                );
              },
              itemBuilder: (context, index) {
                final task = tasks[index];
                return ReorderableDelayedDragStartListener(
                  key: ValueKey(task.id ?? task.createdAt),
                  index: index,
                  child: _TaskRow(
                    task: task,
                    onTap: () => _openTask(context, task),
                    onToggle: () => taskProvider.toggleTask(task),
                    onDelete: () => _confirmDelete(context, task),
                    onStart: task.completed ? null : () => onStartFocus(task),
                  ),
                );
              },
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

// Kept for compatibility with the previous home layout.
// ignore: unused_element
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
    final weekday = const [
      '\u4e00',
      '\u4e8c',
      '\u4e09',
      '\u56db',
      '\u4e94',
      '\u516d',
      '\u65e5',
    ][selectedDate.weekday - 1];
    return GestureDetector(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${selectedDate.month}\u6708${selectedDate.day}\u65e5\u00b7\u661f\u671f$weekday',
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
        const SnackBar(content: Text('\u4fdd\u5b58\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5')),
      );
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
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      setState(() {
        _questionText = JournalEntry.normalizeQuestionText(value);
        _hasLocalEdits = true;
      });
    });
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
        _questionText =
            JournalEntry.normalizeQuestionText(entry?.questionText);
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
                  trailing: IconButton(
                    onPressed: _changeQuestion,
                    padding: EdgeInsets.zero,
                    visualDensity: VisualDensity.compact,
                    icon: const Icon(Icons.edit_outlined, size: 20),
                    tooltip: '\u66f4\u6362\u95ee\u9898',
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '\u201c$_questionText\u201d',
                        style: TextStyle(
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

  void _returnToLastYear() {
    Navigator.of(context).pop(_sameDayLastYear(_selectedDate));
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
                        onPressed: _returnToLastYear,
                        child: const Text('\u53bb\u5e74\u4eca\u65e5'),
                      ),
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
    required this.onTap,
    required this.onToggle,
    required this.onDelete,
    required this.onStart,
  });

  final Task task;
  final VoidCallback onTap;
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
            child: GestureDetector(
              onTap: onTap,
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
                                _formatTaskDuration(task.durationSeconds),
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
  return formatFocusDuration(seconds);
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

// Kept for compatibility with older navigation state.
// ignore: unused_element
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
