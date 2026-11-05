/// 초 → "mm:ss"
String mmss(int seconds) {
  final m = (seconds ~/ 60).toString().padLeft(2, '0');
  final s = (seconds % 60).toString().padLeft(2, '0');
  return '$m:$s';
}

/// 시각 → "오전 8:20"
String timeOfDayKo(DateTime d) {
  final period = d.hour < 12 ? '오전' : '오후';
  final h12 = d.hour % 12 == 0 ? 12 : d.hour % 12;
  return '$period $h12:${d.minute.toString().padLeft(2, '0')}';
}

/// 날짜 → "오늘" / "어제" / "9월 27일"
String dayLabelKo(DateTime d, {DateTime? now}) {
  final n = now ?? DateTime.now();
  final today = DateTime(n.year, n.month, n.day);
  final that = DateTime(d.year, d.month, d.day);
  final diff = today.difference(that).inDays;
  if (diff == 0) return '오늘';
  if (diff == 1) return '어제';
  return '${d.month}월 ${d.day}일';
}

/// "2026년 9월 29일 · 오전 8:20"
String longDateTimeKo(DateTime d) => '${d.year}년 ${d.month}월 ${d.day}일 · ${timeOfDayKo(d)}';

/// 초 → "2분 40초"
String minSecKo(int seconds) => '${seconds ~/ 60}분 ${seconds % 60}초';
