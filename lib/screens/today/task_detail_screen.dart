import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

import '../../models/task.dart';
import '../../providers/task_provider.dart';
import '../../widgets/chrona_widgets.dart';

class TaskDetailScreen extends StatefulWidget {
  const TaskDetailScreen({
    super.key,
    required this.task,
    required this.taskProvider,
  });

  final Task task;
  final TaskProvider taskProvider;

  @override
  State<TaskDetailScreen> createState() => _TaskDetailScreenState();
}

class _TaskDetailScreenState extends State<TaskDetailScreen> {
  late final TextEditingController _titleController;
  late final TextEditingController _noteController;
  late Duration _duration;
  String? _titleError;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.task.title);
    _noteController = TextEditingController(text: widget.task.note ?? '');
    _duration = Duration(seconds: widget.task.durationSeconds);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final title = _titleController.text.trim();
    if (title.isEmpty) {
      setState(() => _titleError = '标题不能为空');
      return;
    }
    if (_duration.inSeconds == 0) return;

    setState(() => _isSaving = true);
    final updated = widget.task.copyWith(
      title: title,
      note: _noteController.text.trim().isEmpty
          ? null
          : _noteController.text.trim(),
      durationSeconds: _duration.inSeconds,
    );

    try {
      await widget.taskProvider.updateTask(updated);
      if (mounted) Navigator.of(context).pop();
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  String get _durationLabel {
    final hours = _duration.inHours;
    final minutes = _duration.inMinutes.remainder(60);
    final seconds = _duration.inSeconds.remainder(60);
    return '${hours.toString().padLeft(2, '0')}:'
        '${minutes.toString().padLeft(2, '0')}:'
        '${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 32),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 40,
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints.tightFor(width: 40, height: 40),
                    icon: const Icon(Icons.arrow_back, size: 29),
                    tooltip: '返回',
                  ),
                ),
              ),
              const SizedBox(height: 54),
              const Text(
                '任务详情',
                style: TextStyle(
                  color: Color(0xFF111111),
                  fontSize: 36,
                  height: 1.05,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 42),
              TextField(
                controller: _titleController,
                onChanged: (_) => setState(() => _titleError = null),
                decoration: InputDecoration(
                  labelText: '任务名称',
                  errorText: _titleError,
                  enabledBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: const UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111)),
                  ),
                ),
              ),
              const SizedBox(height: 28),
              TextField(
                controller: _noteController,
                minLines: 3,
                maxLines: 6,
                decoration: const InputDecoration(
                  labelText: '备注（可选）',
                  alignLabelWithHint: true,
                  enabledBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFFDDDDDD)),
                  ),
                  focusedBorder: UnderlineInputBorder(
                    borderSide: BorderSide(color: Color(0xFF111111)),
                  ),
                ),
              ),
              const SizedBox(height: 34),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    '专注时长',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 18,
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
              const SizedBox(height: 8),
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
                    onTimerDurationChanged: (value) => setState(() {
                      _duration = value;
                    }),
                  ),
                ),
              ),
              const SizedBox(height: 30),
              PrimaryButton(
                label: '保存',
                onPressed: _isSaving ? () {} : _save,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
