String formatFocusTime(DateTime time) {
  return '${time.hour.toString().padLeft(2, '0')}:'
      '${time.minute.toString().padLeft(2, '0')}';
}

String formatFocusDuration(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final minutes = safeSeconds ~/ 60;
  final remainingSeconds = safeSeconds % 60;
  if (minutes == 0) return '$remainingSeconds sec';
  if (remainingSeconds == 0) return '$minutes min';
  return '$minutes min $remainingSeconds sec';
}

String formatFocusHoursMinutes(int seconds) {
  final safeSeconds = seconds < 0 ? 0 : seconds;
  final hours = safeSeconds ~/ Duration.secondsPerHour;
  final minutes = (safeSeconds % Duration.secondsPerHour) ~/ 60;
  if (hours == 0) return '${minutes}m';
  return '${hours}h ${minutes}m';
}

DateTime startOfFocusWeek(DateTime date) {
  final day = DateTime(date.year, date.month, date.day);
  return day.subtract(Duration(days: day.weekday - DateTime.monday));
}

String formatFocusDate(DateTime date) {
  const weekdays = <String>['一', '二', '三', '四', '五', '六', '日'];
  return '${date.month}月${date.day}日·星期${weekdays[date.weekday - 1]}';
}

String formatFocusDayHeading(DateTime date, {DateTime? now}) {
  final current = now ?? DateTime.now();
  final day = DateTime(date.year, date.month, date.day);
  final today = DateTime(current.year, current.month, current.day);
  if (day == today) return '今天';
  if (day == today.subtract(const Duration(days: 1))) return '昨天';
  return '${date.month}月${date.day}日';
}
