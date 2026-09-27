import 'package:flutter/material.dart';

import '../../data/mock_data.dart';
import '../../widgets/chrona_widgets.dart';

class HistoryScreen extends StatelessWidget {
  const HistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            Expanded(
              child: ListView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(24, 12, 24, 28),
                children: [
                  const BrandHeader(),
                  const SizedBox(height: 67),
                  const Text(
                    '记录',
                    style: TextStyle(
                        color: Color(0xFF111111),
                        fontSize: 38,
                        height: 1.05,
                        fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(height: 64),
                  for (var index = 0;
                      index < ChronaMockData.historyGroups.length;
                      index++) ...[
                    _HistoryGroup(group: ChronaMockData.historyGroups[index]),
                    if (index != ChronaMockData.historyGroups.length - 1)
                      const SizedBox(height: 65),
                  ],
                ],
              ),
            ),
            ChronaBottomNavigation(
              selectedIndex: 1,
              onTabSelected: (index) {
                if (index == 0) {
                  Navigator.of(context).popUntil((route) => route.isFirst);
                }
              },
            ),
            SizedBox(height: MediaQuery.paddingOf(context).bottom),
          ],
        ),
      ),
    );
  }
}

class _HistoryGroup extends StatelessWidget {
  const _HistoryGroup({required this.group});

  final HistoryGroupMockData group;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          group.label,
          style: const TextStyle(
              color: Color(0xFF111111),
              fontSize: 34,
              height: 1.1,
              fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 13),
        Text(
          group.date,
          style: const TextStyle(
              color: Color(0xFF8B8B8B), fontSize: 20, height: 1.1),
        ),
        const SizedBox(height: 33),
        for (final entry in group.entries) _HistoryEntry(entry: entry),
      ],
    );
  }
}

class _HistoryEntry extends StatelessWidget {
  const _HistoryEntry({required this.entry});

  final HistoryEntryMockData entry;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(bottom: 25, top: 2),
      margin: const EdgeInsets.only(bottom: 24),
      decoration: const BoxDecoration(
        border: Border(bottom: BorderSide(color: Color(0xFFE9E9E9))),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 140,
            height: 28,
            child: FittedBox(
              fit: BoxFit.scaleDown,
              alignment: Alignment.centerLeft,
              child: Text(
                entry.time,
                maxLines: 1,
                softWrap: false,
                style: const TextStyle(
                    color: Color(0xFF858585), fontSize: 18, height: 1.25),
              ),
            ),
          ),
          Container(
            width: 1,
            height: 64,
            margin: const EdgeInsets.only(right: 24),
            color: const Color(0xFFE1E1E1),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  entry.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 21,
                      height: 1.25,
                      fontWeight: FontWeight.w500),
                ),
                const SizedBox(height: 7),
                Text(
                  entry.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                      color: Color(0xFF858585), fontSize: 17, height: 1.3),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
