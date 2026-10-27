import '../models/workout_session.dart';

/// 시간을 뗀 날짜 (같은 날의 기록을 묶을 때 사용)
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 그 주의 월요일
DateTime weekStartOf(DateTime d) {
  final day = dayOf(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// 하루치 운동 기록. 운동 세션 1개 = 세트 1개
class DaySummary {
  DaySummary(this.date, this.sets);

  final DateTime date;
  final List<WorkoutSession> sets; // 시간순

  bool get isEmpty => sets.isEmpty;
  int get setCount => sets.length;
  int get totalReps => sets.fold<int>(0, (a, s) => a + s.totalReps);
  int get goodReps => sets.fold<int>(0, (a, s) => a + s.goodReps);
  int get totalSec => sets.fold<int>(0, (a, s) => a + s.durationSec);
  double get averageScore => sets.isEmpty
      ? 0
      : sets.fold<double>(0, (a, s) => a + s.averageScore) / sets.length;
  double get accuracy => totalReps == 0 ? 0 : goodReps / totalReps * 100;
}

/// 일주일(월~일) 합계
class WeekSummary {
  WeekSummary(this.days);

  final List<DaySummary> days; // 7개

  Iterable<WorkoutSession> get _sets => days.expand((d) => d.sets);

  int get activeDays => days.where((d) => !d.isEmpty).length;
  int get setCount => _sets.length;
  int get totalReps => _sets.fold<int>(0, (a, s) => a + s.totalReps);
  int get goodReps => _sets.fold<int>(0, (a, s) => a + s.goodReps);
  double get averageScore => setCount == 0
      ? 0
      : _sets.fold<double>(0, (a, s) => a + s.averageScore) / setCount;
  double get accuracy => totalReps == 0 ? 0 : goodReps / totalReps * 100;
}

/// 운동 기록을 날짜별로 묶음
Map<DateTime, DaySummary> groupByDay(List<WorkoutSession> sessions) {
  final map = <DateTime, List<WorkoutSession>>{};
  for (final s in sessions) {
    map.putIfAbsent(dayOf(s.startedAt), () => []).add(s);
  }
  return {
    for (final e in map.entries)
      e.key: DaySummary(
        e.key,
        e.value..sort((a, b) => a.startedAt.compareTo(b.startedAt)),
      ),
  };
}

/// weekStart(월요일)부터 7일치. 기록이 없는 날도 빈 DaySummary로 채움
List<DaySummary> weekDays(Map<DateTime, DaySummary> byDay, DateTime weekStart) {
  return List.generate(7, (i) {
    final d = DateTime(weekStart.year, weekStart.month, weekStart.day + i);
    return byDay[d] ?? DaySummary(d, const []);
  });
}

// ---------------- 표시용 글자 ----------------

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String weekdayKo(DateTime d) => _weekdays[d.weekday - 1];

String formatDateKo(DateTime d) => '${d.month}월 ${d.day}일 (${weekdayKo(d)})';

String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatDuration(int sec) {
  final m = sec ~/ 60;
  final s = sec % 60;
  if (m == 0) return '$s초';
  return s == 0 ? '$m분' : '$m분 $s초';
}

String formatWeekRange(DateTime weekStart) {
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  return '${weekStart.month}.${weekStart.day} – ${end.month}.${end.day}';
}
