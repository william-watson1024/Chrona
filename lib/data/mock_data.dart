abstract final class ChronaMockData {
  static const currentTaskTitle = '阅读 Orca 论文';
  static const currentTaskNote = '继续看 Section 3';
  static const focusTime = '20:00 - 20:25';
  static const focusDuration = '25 min';
  static const focusNote =
      '看完 Introduction 和 Section 2，\n整理了 Continuous Batching 笔记。';

  static const historyGroups = <HistoryGroupMockData>[
    HistoryGroupMockData(
      label: '今天',
      date: '9月27日 · 星期六',
      entries: [
        HistoryEntryMockData(
          time: '20:00 — 20:25',
          title: currentTaskTitle,
          note: '看完 Introduction 和 Section 2',
        ),
        HistoryEntryMockData(
          time: '18:30 — 18:55',
          title: '写 RagForge',
          note: '完成 DocumentService 设计',
        ),
        HistoryEntryMockData(
          time: '14:00 — 14:25',
          title: '整理笔记',
          note: '整理 SGLang 阅读笔记',
        ),
      ],
    ),
    HistoryGroupMockData(
      label: '昨天',
      date: '9月26日 · 星期五',
      entries: [
        HistoryEntryMockData(
          time: '21:00 — 21:50',
          title: '看技术分享',
          note: '看完 AI Infra 系列第 1 讲，记录了一些要点',
        ),
        HistoryEntryMockData(
          time: '10:30 — 11:20',
          title: '健身',
          note: '胸 + 肩，完成计划的训练内容',
        ),
      ],
    ),
  ];
}

class HistoryGroupMockData {
  const HistoryGroupMockData({
    required this.label,
    required this.date,
    required this.entries,
  });

  final String label;
  final String date;
  final List<HistoryEntryMockData> entries;
}

class HistoryEntryMockData {
  const HistoryEntryMockData({
    required this.time,
    required this.title,
    required this.note,
  });

  final String time;
  final String title;
  final String note;
}
