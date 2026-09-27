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
            label: '今天',
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
