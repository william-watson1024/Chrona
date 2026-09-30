import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/focus_settings_provider.dart';
import '../../services/birthday_settings.dart';
import '../../services/data_transfer_service.dart';
import '../../widgets/chrona_date_picker.dart';
import '../../widgets/chrona_widgets.dart';
import '../history/history_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final inheritedProvider =
        Provider.of<FocusSettingsProvider?>(context, listen: false);
    if (inheritedProvider != null) return const _SettingsContent();

    return ChangeNotifierProvider(
      create: (_) => FocusSettingsProvider()..load(),
      child: const _SettingsContent(),
    );
  }
}

class _SettingsContent extends StatefulWidget {
  const _SettingsContent();

  @override
  State<_SettingsContent> createState() => _SettingsContentState();
}

class _SettingsContentState extends State<_SettingsContent> {
  static const _breakOptions = <int>[
    5 * 60,
    10 * 60,
    15 * 60,
    20 * 60,
    30 * 60,
  ];

  final _dataTransferService = DataTransferService();
  bool _isTransferring = false;
  DateTime? _birthday;
  bool _birthdayLoading = true;

  @override
  void initState() {
    super.initState();
    _loadBirthday();
  }

  Future<void> _loadBirthday() async {
    final birthday = await BirthdaySettings.load();
    if (!mounted) return;
    setState(() {
      _birthday = birthday;
      _birthdayLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: Consumer<FocusSettingsProvider>(
                builder: (context, settings, child) {
                  if (settings.isLoading) {
                    return const Center(
                      child: CircularProgressIndicator(
                        strokeWidth: 1.5,
                        color: Color(0xFF111111),
                      ),
                    );
                  }

                  return ListView(
                    padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                    children: [
                      const BrandHeader(showSettingsButton: false),
                      const SizedBox(height: 67),
                      const Text(
                        '\u8bbe\u7f6e',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 38,
                          height: 1.05,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 54),
                      _DurationSetting(
                        label: '\u4f11\u606f\u65f6\u957f',
                        value: settings.breakDurationSeconds,
                        options: _breakOptions,
                        onChanged: settings.updateBreakDuration,
                      ),
                      const SizedBox(height: 44),
                      _BirthdaySetting(
                        birthday: _birthday,
                        loading: _birthdayLoading,
                        onTap: () => _pickBirthday(context),
                        onClear: _birthday == null ? null : _clearBirthday,
                      ),
                      const SizedBox(height: 52),
                      const Text(
                        '\u6570\u636e',
                        style: TextStyle(
                          color: Color(0xFF111111),
                          fontSize: 20,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 10),
                      _DataAction(
                        icon: Icons.upload_outlined,
                        title: '\u5bfc\u51fa\u6570\u636e',
                        subtitle:
                            '\u4fdd\u5b58\u4efb\u52a1\u3001\u4e13\u6ce8\u8bb0\u5f55\u548c\u65e5\u8bb0',
                        enabled: !_isTransferring,
                        onTap: () => _exportData(context),
                      ),
                      _DataAction(
                        icon: Icons.download_outlined,
                        title: '\u5bfc\u5165\u6570\u636e',
                        subtitle:
                            '\u4ece JSON \u5907\u4efd\u6062\u590d\u6570\u636e',
                        enabled: !_isTransferring,
                        onTap: () => _importData(context, settings),
                      ),
                    ],
                  );
                },
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 2,
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                } else if (index == 1) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const HistoryScreen()),
                  );
                }
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }

  Future<void> _exportData(BuildContext context) async {
    setState(() => _isTransferring = true);
    try {
      final uri = await _dataTransferService.exportData();
      if (!context.mounted || uri == null) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('\u6570\u636e\u5df2\u5bfc\u51fa')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '\u5bfc\u51fa\u5931\u8d25\uff0c\u8bf7\u7a0d\u540e\u91cd\u8bd5'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _importData(
    BuildContext context,
    FocusSettingsProvider settings,
  ) async {
    setState(() => _isTransferring = true);
    try {
      final payload = await _dataTransferService.pickBackup();
      if (!context.mounted || payload == null) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          backgroundColor: Colors.white,
          surfaceTintColor: Colors.transparent,
          title: const Text('\u5bfc\u5165\u6570\u636e'),
          content: const Text(
            '\u5bfc\u5165\u4f1a\u8986\u76d6\u5f53\u524d\u7684\u4efb\u52a1\u3001\u4e13\u6ce8\u8bb0\u5f55\u548c\u65e5\u8bb0\u3002\n'
            '\u5efa\u8bae\u5148\u5bfc\u51fa\u5f53\u524d\u6570\u636e\u3002',
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
              child: const Text('\u5bfc\u5165'),
            ),
          ],
        ),
      );
      if (confirmed != true || !context.mounted) return;

      await _dataTransferService.importData(payload);
      await _loadBirthday();
      final importedSettings = payload['settings'];
      if (importedSettings is Map &&
          importedSettings['break_duration_seconds'] is num) {
        final duration =
            (importedSettings['break_duration_seconds'] as num).toInt();
        if (duration > 0) await settings.updateBreakDuration(duration);
      }
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            '\u5bfc\u5165\u6210\u529f\uff0c\u8bf7\u91cd\u65b0\u6253\u5f00 App \u4ee5\u5237\u65b0\u6570\u636e',
          ),
        ),
      );
    } on FormatException {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
            content: Text('\u5907\u4efd\u6587\u4ef6\u683c\u5f0f\u65e0\u6548')),
      );
    } catch (_) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
              '\u5bfc\u5165\u5931\u8d25\uff0c\u8bf7\u68c0\u67e5\u6587\u4ef6'),
        ),
      );
    } finally {
      if (mounted) setState(() => _isTransferring = false);
    }
  }

  Future<void> _pickBirthday(BuildContext context) async {
    final initialDate = _birthday ?? DateTime(2000, 1, 1);
    final picked = await showDialog<DateTime>(
      context: context,
      barrierDismissible: false,
      builder: (_) => ChronaDatePickerDialog(
        initialDate: initialDate,
        showRelativeActions: false,
        confirmLabel: '确定',
      ),
    );
    if (picked == null) return;
    await BirthdaySettings.save(month: picked.month, day: picked.day);
    if (!mounted) return;
    setState(() => _birthday = DateTime(2000, picked.month, picked.day));
  }

  Future<void> _clearBirthday() async {
    await BirthdaySettings.clear();
    if (!mounted) return;
    setState(() => _birthday = null);
  }
}

class _DataAction extends StatelessWidget {
  const _DataAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1 : 0.45,
      child: InkWell(
        onTap: enabled ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 15),
          decoration: const BoxDecoration(
            border: Border(
              bottom: BorderSide(color: Color(0xFFE9E9E9)),
            ),
          ),
          child: Row(
            children: [
              Icon(icon, size: 22, color: const Color(0xFF111111)),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 17,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: Color(0xFF858585),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right, color: Color(0xFF858585)),
            ],
          ),
        ),
      ),
    );
  }
}

class _DurationSetting extends StatelessWidget {
  const _DurationSetting({
    required this.label,
    required this.value,
    required this.options,
    required this.onChanged,
  });

  final String label;
  final int value;
  final List<int> options;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 20,
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
        DropdownButton<int>(
          value: options.contains(value) ? value : options.last,
          underline: const SizedBox.shrink(),
          items: [
            for (final option in options)
              DropdownMenuItem(
                value: option,
                child: Text(_formatDuration(option)),
              ),
          ],
          onChanged: (newValue) {
            if (newValue != null) onChanged(newValue);
          },
        ),
      ],
    );
  }

  String _formatDuration(int seconds) {
    if (seconds < 60) return '$seconds \u79d2';
    return '${seconds ~/ 60} \u5206\u949f';
  }
}

class _BirthdaySetting extends StatelessWidget {
  const _BirthdaySetting({
    required this.birthday,
    required this.loading,
    required this.onTap,
    required this.onClear,
  });

  final DateTime? birthday;
  final bool loading;
  final VoidCallback onTap;
  final VoidCallback? onClear;

  @override
  Widget build(BuildContext context) {
    final value = loading
        ? '读取中…'
        : birthday == null
            ? '未设置'
            : '${birthday!.month}月${birthday!.day}日';
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Row(
          children: [
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '生日',
                    style: TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 20,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  SizedBox(height: 4),
                  Text(
                    '生日当天会有特定的问答',
                    style: TextStyle(
                      color: Color(0xFF858585),
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              value,
              style: const TextStyle(color: Color(0xFF858585), fontSize: 16),
            ),
            const SizedBox(width: 5),
            if (onClear != null)
              IconButton(
                onPressed: onClear,
                tooltip: '清除生日',
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close, size: 18),
              )
            else
              const Icon(Icons.chevron_right, color: Color(0xFF858585)),
          ],
        ),
      ),
    );
  }
}
