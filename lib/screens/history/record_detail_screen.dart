import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/focus_session.dart';
import '../../providers/focus_session_provider.dart';
import '../../utils/focus_formatters.dart';
import '../settings/settings_screen.dart';

class RecordDetailScreen extends StatelessWidget {
  const RecordDetailScreen({super.key, required this.session});

  final FocusSession session;

  @override
  Widget build(BuildContext context) {
    final inheritedProvider =
        Provider.of<FocusSessionProvider?>(context, listen: false);
    if (inheritedProvider != null) {
      return _RecordDetailContent(session: session);
    }

    return ChangeNotifierProvider(
      create: (_) => FocusSessionProvider()..loadSessions(),
      child: _RecordDetailContent(session: session),
    );
  }
}

class _RecordDetailContent extends StatefulWidget {
  const _RecordDetailContent({required this.session});

  final FocusSession session;

  @override
  State<_RecordDetailContent> createState() => _RecordDetailContentState();
}

class _RecordDetailContentState extends State<_RecordDetailContent> {
  late final TextEditingController _noteController;
  bool _isEditing = false;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _noteController = TextEditingController(text: widget.session.note ?? '');
  }

  @override
  void dispose() {
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _saveNote(FocusSession session) async {
    if (_isSaving) return;
    setState(() => _isSaving = true);
    final updated =
        await context.read<FocusSessionProvider>().updateSessionNote(
              session,
              _noteController.text,
            );
    if (!mounted) return;
    setState(() {
      _isSaving = false;
      _isEditing = updated == null ? _isEditing : false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FocusSessionProvider>();
    final session = provider.sessions.cast<FocusSession?>().firstWhere(
              (item) => item?.id == widget.session.id,
              orElse: () => widget.session,
            ) ??
        widget.session;
    final note = session.note?.trim();

    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(24, 12, 24, 40),
          children: [
            _RecordTopBar(title: formatFocusDate(session.startedAt)),
            const SizedBox(height: 66),
            Text(
              session.taskTitleSnapshot,
              style: const TextStyle(
                color: Color(0xFF111111),
                fontSize: 32,
                height: 1.15,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),
            Text(
              '${formatFocusTime(session.startedAt)} — '
              '${formatFocusTime(session.endedAt)} · '
              '${formatFocusDuration(session.actualDurationSeconds)}',
              style: const TextStyle(
                color: Color(0xFF858585),
                fontSize: 19,
              ),
            ),
            const SizedBox(height: 58),
            const Text(
              '这段时间做了什么？',
              style: TextStyle(
                color: Color(0xFF111111),
                fontSize: 21,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 16),
            if (_isEditing)
              TextField(
                controller: _noteController,
                minLines: 6,
                maxLines: 12,
                textAlignVertical: TextAlignVertical.top,
                autofocus: true,
                decoration: InputDecoration(
                  contentPadding: const EdgeInsets.all(20),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFE0E0E0)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFF111111)),
                  ),
                ),
              )
            else
              Text(
                note == null || note.isEmpty ? '未填写记录' : note,
                style: const TextStyle(
                  color: Color(0xFF858585),
                  fontSize: 18,
                  height: 1.5,
                ),
              ),
            const SizedBox(height: 24),
            if (_isEditing)
              Row(
                children: [
                  TextButton(
                    onPressed: _isSaving
                        ? null
                        : () => setState(() {
                              _isEditing = false;
                              _noteController.text = session.note ?? '';
                            }),
                    child: const Text('取消'),
                  ),
                  const SizedBox(width: 12),
                  FilledButton(
                    onPressed: _isSaving ? null : () => _saveNote(session),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF111111),
                      foregroundColor: Colors.white,
                    ),
                    child: Text(_isSaving ? '保存中' : '保存'),
                  ),
                ],
              )
            else
              TextButton(
                onPressed: () => setState(() {
                  _noteController.text = session.note ?? '';
                  _isEditing = true;
                }),
                style: TextButton.styleFrom(
                  foregroundColor: const Color(0xFF111111),
                ),
                child: const Text('编辑记录'),
              ),
            const SizedBox(height: 38),
            const Divider(color: Color(0xFFE9E9E9)),
            const SizedBox(height: 24),
            _RecordMetaRow(
              label: '状态',
              value: session.status == FocusSessionStatus.completed
                  ? '已完成'
                  : '提前结束',
            ),
            const SizedBox(height: 18),
            _RecordMetaRow(label: '任务', value: session.taskTitleSnapshot),
          ],
        ),
      ),
    );
  }
}

class _RecordTopBar extends StatelessWidget {
  const _RecordTopBar({required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: () => Navigator.of(context).pop(),
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints.tightFor(width: 40, height: 40),
          icon: const Icon(Icons.arrow_back, size: 28),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 22,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        IconButton(
          onPressed: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const SettingsScreen()),
          ),
          icon: const Icon(Icons.settings_outlined, size: 24),
          color: const Color(0xFF111111),
          tooltip: '设置',
        ),
      ],
    );
  }
}

class _RecordMetaRow extends StatelessWidget {
  const _RecordMetaRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 60,
          child: Text(
            label,
            style: const TextStyle(color: Color(0xFF858585), fontSize: 17),
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(color: Color(0xFF111111), fontSize: 17),
          ),
        ),
      ],
    );
  }
}
