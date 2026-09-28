import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

class BrandHeader extends StatelessWidget {
  const BrandHeader({super.key, this.onSettingsPressed});

  final VoidCallback? onSettingsPressed;

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
          onPressed: onSettingsPressed,
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

class ChronaBottomNavigation extends StatelessWidget {
  const ChronaBottomNavigation({
    super.key,
    required this.selectedIndex,
    required this.onTabSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onTabSelected;

  @override
  Widget build(BuildContext context) {
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
            label: '今朝',
            icon: Icons.home_filled,
            selected: selectedIndex == 0,
            onTap: () => onTabSelected(0),
          ),
          _NavItem(
            label: '记录',
            icon: Icons.bar_chart_rounded,
            selected: selectedIndex == 1,
            onTap: () => onTabSelected(1),
          ),
          _NavItem(
            label: '设置',
            icon: Icons.person_outline,
            selected: selectedIndex == 2,
            onTap: () => onTabSelected(2),
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

class PrimaryButton extends StatelessWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 68,
      width: double.infinity,
      child: FilledButton(
        onPressed: onPressed,
        style: FilledButton.styleFrom(
          backgroundColor: const Color(0xFF111111),
          foregroundColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          textStyle: const TextStyle(fontSize: 20, fontWeight: FontWeight.w500),
        ),
        child: Text(label),
      ),
    );
  }
}

/// Duration picker used by task creation and task editing.
///
/// Unlike Flutter's CupertinoTimerPicker, the hour column is also looping so
/// all three columns have the same scroll behavior.
class LoopingDurationPicker extends StatefulWidget {
  const LoopingDurationPicker({
    super.key,
    required this.initialDuration,
    required this.onDurationChanged,
  });

  final Duration initialDuration;
  final ValueChanged<Duration> onDurationChanged;

  @override
  State<LoopingDurationPicker> createState() => _LoopingDurationPickerState();
}

class _LoopingDurationPickerState extends State<LoopingDurationPicker> {
  late int _hours;
  late int _minutes;
  late int _seconds;
  late final FixedExtentScrollController _hourController;
  late final FixedExtentScrollController _minuteController;
  late final FixedExtentScrollController _secondController;

  @override
  void initState() {
    super.initState();
    final totalSeconds =
        widget.initialDuration.inSeconds.clamp(0, 23 * 3600 + 59 * 60 + 59);
    _hours = totalSeconds ~/ 3600;
    _minutes = (totalSeconds % 3600) ~/ 60;
    _seconds = totalSeconds % 60;
    _hourController = FixedExtentScrollController(initialItem: _hours);
    _minuteController = FixedExtentScrollController(initialItem: _minutes);
    _secondController = FixedExtentScrollController(initialItem: _seconds);
  }

  @override
  void dispose() {
    _hourController.dispose();
    _minuteController.dispose();
    _secondController.dispose();
    super.dispose();
  }

  void _changed({int? hours, int? minutes, int? seconds}) {
    setState(() {
      _hours = hours ?? _hours;
      _minutes = minutes ?? _minutes;
      _seconds = seconds ?? _seconds;
    });
    widget.onDurationChanged(
      Duration(hours: _hours, minutes: _minutes, seconds: _seconds),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoTheme(
      data: const CupertinoThemeData(
        brightness: Brightness.light,
        primaryColor: Color(0xFF111111),
      ),
      child: Row(
        children: [
          Expanded(
            child: _buildPicker(
              controller: _hourController,
              count: 24,
              onChanged: (value) => _changed(hours: value % 24),
            ),
          ),
          const _DurationPickerSeparator(),
          Expanded(
            child: _buildPicker(
              controller: _minuteController,
              count: 60,
              onChanged: (value) => _changed(minutes: value % 60),
            ),
          ),
          const _DurationPickerSeparator(),
          Expanded(
            child: _buildPicker(
              controller: _secondController,
              count: 60,
              onChanged: (value) => _changed(seconds: value % 60),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPicker({
    required FixedExtentScrollController controller,
    required int count,
    required ValueChanged<int> onChanged,
  }) {
    return CupertinoPicker(
      scrollController: controller,
      itemExtent: 32,
      looping: true,
      squeeze: 1.25,
      magnification: 34 / 32,
      backgroundColor: Colors.transparent,
      onSelectedItemChanged: onChanged,
      children: [
        for (var index = 0; index < count; index++)
          Text(
            index.toString().padLeft(2, '0'),
            maxLines: 1,
            softWrap: false,
          ),
      ],
    );
  }
}

class _DurationPickerSeparator extends StatelessWidget {
  const _DurationPickerSeparator();

  @override
  Widget build(BuildContext context) {
    return const Text(
      ':',
      style: TextStyle(
        color: Color(0xFF111111),
        fontSize: 22,
        fontWeight: FontWeight.w600,
      ),
    );
  }
}
