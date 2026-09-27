import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

class TodoTask {
  TodoTask({
    required this.id,
    required this.title,
    required this.note,
    required this.focusMinutes,
    this.isCompleted = false,
  });

  final String id;
  final String title;
  final String note;
  final int focusMinutes;
  bool isCompleted;
}

class TodayViewModel extends ChangeNotifier {
  TodayViewModel()
      : _tasks = [
          TodoTask(
            id: 'orca',
            title: '阅读 Orca 论文',
            note: '继续看 Section 3',
            focusMinutes: 25,
          ),
          TodoTask(
            id: 'ragforge',
            title: '写 RagForge',
            note: '实现文档解析接口',
            focusMinutes: 50,
          ),
          TodoTask(
            id: 'homework',
            title: '上课作业',
            note: '完成第二题',
            focusMinutes: 25,
            isCompleted: true,
          ),
          TodoTask(
            id: 'workout',
            title: '健身',
            note: '胸 + 肩',
            focusMinutes: 50,
          ),
          TodoTask(
            id: 'notes',
            title: '整理笔记',
            note: 'SGLang 阅读笔记',
            focusMinutes: 25,
          ),
          TodoTask(
            id: 'sharing',
            title: '看技术分享',
            note: 'AI Infra 系列',
            focusMinutes: 50,
            isCompleted: true,
          ),
        ];

  final List<TodoTask> _tasks;
  int _selectedTab = 0;

  List<TodoTask> get tasks => List.unmodifiable(_tasks);
  int get selectedTab => _selectedTab;
  int get completedCount => _tasks.where((task) => task.isCompleted).length;

  void toggleTask(TodoTask task) {
    task.isCompleted = !task.isCompleted;
    notifyListeners();
  }

  void addTask(String title) {
    final trimmedTitle = title.trim();
    if (trimmedTitle.isEmpty) return;

    _tasks.add(
      TodoTask(
        id: 'custom-${DateTime.now().microsecondsSinceEpoch}',
        title: trimmedTitle,
        note: '待补充',
        focusMinutes: 25,
      ),
    );
    notifyListeners();
  }

  void selectTab(int index) {
    if (_selectedTab == index) return;
    _selectedTab = index;
    notifyListeners();
  }

  void onStartFocus(TodoTask task) {
    debugPrint('onStartFocus(${task.title})');
  }
}

class TodayScreen extends StatelessWidget {
  const TodayScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            const Expanded(child: _TodayTabContent()),
            const _BottomNavigation(),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class _TodayTabContent extends StatelessWidget {
  const _TodayTabContent();

  @override
  Widget build(BuildContext context) {
    return Consumer<TodayViewModel>(
      builder: (context, viewModel, child) {
        if (viewModel.selectedTab != 0) {
          return _PlaceholderTab(
            title: viewModel.selectedTab == 1 ? '记录' : '设置',
          );
        }
        return const _TodayHomeContent();
      },
    );
  }
}

class _TodayHomeContent extends StatelessWidget {
  const _TodayHomeContent();

  @override
  Widget build(BuildContext context) {
    final viewModel = context.watch<TodayViewModel>();

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 0),
          sliver: SliverToBoxAdapter(
            child: Column(
              children: [
                const _BrandHeader(),
                const SizedBox(height: 48),
                _TodaySummary(completedCount: viewModel.completedCount),
                const SizedBox(height: 27),
              ],
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 24),
          sliver: SliverList.separated(
            itemCount: viewModel.tasks.length,
            itemBuilder: (context, index) {
              final task = viewModel.tasks[index];
              return _TaskRow(
                task: task,
                onToggle: () => viewModel.toggleTask(task),
                onStart: task.isCompleted
                    ? null
                    : () => viewModel.onStartFocus(task),
              );
            },
            separatorBuilder: (_, __) => const SizedBox(height: 0),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(24, 18, 24, 0),
          sliver: SliverToBoxAdapter(
            child: _AddTaskButton(
              onPressed: () => _showAddTaskDialog(context),
            ),
          ),
        ),
        const SliverPadding(
          padding: EdgeInsets.fromLTRB(28, 48, 24, 24),
          sliver: SliverToBoxAdapter(child: _BrandQuote()),
        ),
      ],
    );
  }

  Future<void> _showAddTaskDialog(BuildContext context) async {
    final controller = TextEditingController();
    final title = await showDialog<String>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('添加任务'),
          content: TextField(
            controller: controller,
            autofocus: true,
            textInputAction: TextInputAction.done,
            decoration: const InputDecoration(
              hintText: '输入任务名称',
              enabledBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFFDDDDDD)),
              ),
              focusedBorder: UnderlineInputBorder(
                borderSide: BorderSide(color: Color(0xFF111111)),
              ),
            ),
            onSubmitted: (_) =>
                Navigator.of(dialogContext).pop(controller.text),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(dialogContext).pop(controller.text),
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFF111111),
                foregroundColor: Colors.white,
              ),
              child: const Text('添加'),
            ),
          ],
        );
      },
    );
    controller.dispose();

    if (title != null && context.mounted) {
      context.read<TodayViewModel>().addTask(title);
    }
  }
}

class _BrandHeader extends StatelessWidget {
  const _BrandHeader();

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '拾 年',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 31,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 5,
                ),
              ),
              SizedBox(height: 5),
              Text(
                'C H R O N A',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 14,
                  height: 1,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 3.1,
                ),
              ),
            ],
          ),
        ),
        IconButton(
          onPressed: () {},
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 32, height: 32),
          icon: const Icon(Icons.settings_outlined, size: 23),
          color: const Color(0xFF111111),
          tooltip: '设置',
        ),
      ],
    );
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
              Text(
                '今天',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 38,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: 13),
              FittedBox(
                fit: BoxFit.scaleDown,
                alignment: Alignment.centerLeft,
                child: Text(
                  '9 月 27 日 · 星期六',
                  style: TextStyle(
                    color: Color(0xFF8B8B8B),
                    fontSize: 19,
                    height: 1.1,
                    letterSpacing: 1.1,
                  ),
                ),
              ),
            ],
          ),
        ),
        _StatBlock(value: '$completedCount', label: '已完成'),
        Container(
          width: 1,
          height: 48,
          margin: const EdgeInsets.symmetric(horizontal: 17),
          color: const Color(0xFFE6E6E6),
        ),
        const _StatBlock(value: '3.5', label: '专注时长 (h)'),
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
        Text(
          value,
          style: const TextStyle(
            color: Color(0xFF111111),
            fontSize: 30,
            height: 1,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 10),
        Text(
          label,
          style: const TextStyle(
            color: Color(0xFF8B8B8B),
            fontSize: 15,
            height: 1,
          ),
        ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({
    required this.task,
    required this.onToggle,
    required this.onStart,
  });

  final TodoTask task;
  final VoidCallback onToggle;
  final VoidCallback? onStart;

  @override
  Widget build(BuildContext context) {
    final textDecoration = task.isCompleted ? TextDecoration.lineThrough : null;
    final contentColor =
        task.isCompleted ? const Color(0xFF6F6F6F) : const Color(0xFF111111);

    return Container(
      constraints: const BoxConstraints(minHeight: 94),
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFE9E9E9), width: 1),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          _CompletionButton(
            completed: task.isCompleted,
            onPressed: onToggle,
          ),
          const SizedBox(width: 17),
          Expanded(
            child: Opacity(
              opacity: task.isCompleted ? 0.65 : 1,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                      decoration: textDecoration,
                      decorationThickness: 1.5,
                    ),
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      const Icon(
                        Icons.notes_outlined,
                        size: 18,
                        color: Color(0xFF8A8A8A),
                      ),
                      const SizedBox(width: 7),
                      Flexible(
                        child: Text(
                          task.note,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                            color: Color(0xFF8A8A8A),
                            fontSize: 16,
                            height: 1.15,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(width: 9),
          Opacity(
            opacity: task.isCompleted ? 0.65 : 1,
            child: Text(
              '${task.focusMinutes} min',
              style: const TextStyle(
                color: Color(0xFF858585),
                fontSize: 16,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(width: 17),
          _StartButton(onPressed: onStart),
        ],
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
    return Semantics(
      button: true,
      label: completed ? '标记为未完成' : '标记为已完成',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: completed ? const Color(0xFF111111) : Colors.transparent,
            border: completed
                ? null
                : Border.all(color: const Color(0xFF777777), width: 1.5),
          ),
          child: completed
              ? const Icon(Icons.check, color: Colors.white, size: 23)
              : null,
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
    return Semantics(
      button: true,
      label: enabled ? '开始专注' : '任务已完成',
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 42,
          height: 42,
          decoration: const BoxDecoration(
            shape: BoxShape.circle,
            color: Color(0xFFF0F0F0),
          ),
          child: Icon(
            Icons.play_arrow_rounded,
            size: 23,
            color: enabled ? const Color(0xFF111111) : const Color(0xFFC9C9C9),
          ),
        ),
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
            borderRadius: BorderRadius.circular(10),
          ),
        ),
        icon: const Icon(Icons.add, size: 27),
        label: const Text(
          '添加任务',
          style: TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
        ),
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
        Container(
          width: 4,
          height: 112,
          color: const Color(0xFFE2E2E2),
        ),
        const SizedBox(width: 18),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '不是时间不够用，\n而是我们没有好好拾起它。',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 17,
                height: 1.7,
              ),
            ),
            SizedBox(height: 5),
            Text(
              '— 拾年',
              style: TextStyle(
                color: Color(0xFF888888),
                fontSize: 16,
                height: 1.3,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _BottomNavigation extends StatelessWidget {
  const _BottomNavigation();

  @override
  Widget build(BuildContext context) {
    final selectedTab = context.watch<TodayViewModel>().selectedTab;
    return Container(
      height: 82,
      decoration: const BoxDecoration(
        border: Border(top: BorderSide(color: Color(0xFFE9E9E9))),
        color: Colors.white,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _NavItem(
            label: '今天',
            icon: Icons.home_filled,
            selected: selectedTab == 0,
            onTap: () => context.read<TodayViewModel>().selectTab(0),
          ),
          _NavItem(
            label: '记录',
            icon: Icons.bar_chart_rounded,
            selected: selectedTab == 1,
            onTap: () => context.read<TodayViewModel>().selectTab(1),
          ),
          _NavItem(
            label: '设置',
            icon: Icons.person_outline,
            selected: selectedTab == 2,
            onTap: () => context.read<TodayViewModel>().selectTab(2),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatelessWidget {
  const _NavItem({
    required this.label,
    required this.icon,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = selected ? const Color(0xFF111111) : const Color(0xFF999999);
    return InkWell(
      onTap: onTap,
      child: SizedBox(
        width: 80,
        height: 82,
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 27, color: color),
            const SizedBox(height: 5),
            Text(
              label,
              style: TextStyle(color: color, fontSize: 14, height: 1.1),
            ),
          ],
        ),
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
          const _BrandHeader(),
          const SizedBox(height: 64),
          Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 36,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            '这里将在后续版本开放。',
            style: TextStyle(color: Color(0xFF888888), fontSize: 17),
          ),
        ],
      ),
    );
  }
}
