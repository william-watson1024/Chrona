import 'package:flutter/material.dart';

import '../models/focus_session.dart';
import '../utils/focus_formatters.dart';

class FocusSessionEntry extends StatelessWidget {
  const FocusSessionEntry({
    super.key,
    required this.session,
    this.onTap,
  });

  final FocusSession session;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final duration = formatFocusDuration(session.actualDurationSeconds);
    final durationLabel = session.status == FocusSessionStatus.cancelled
        ? '$duration · 提前结束'
        : duration;
    final note = session.note?.trim();

    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 18),
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: Color(0xFFE9E9E9))),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: 101,
              child: Text(
                '${formatFocusTime(session.startedAt)} — '
                '${formatFocusTime(session.endedAt)}',
                style: const TextStyle(
                  color: Color(0xFF858585),
                  fontSize: 17,
                  height: 1.3,
                ),
              ),
            ),
            const SizedBox(width: 18),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    session.taskTitleSnapshot,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Color(0xFF111111),
                      fontSize: 20,
                      height: 1.25,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (note != null && note.isNotEmpty) ...[
                    const SizedBox(height: 5),
                    Text(
                      note,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: Color(0xFF858585),
                        fontSize: 17,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 12),
            SizedBox(
              width: 78,
              child: Text(
                durationLabel,
                textAlign: TextAlign.right,
                style: const TextStyle(
                  color: Color(0xFF858585),
                  fontSize: 16,
                  height: 1.3,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
