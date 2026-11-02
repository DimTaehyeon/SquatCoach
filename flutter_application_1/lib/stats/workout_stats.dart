import '../models/workout_session.dart';

/// 시간을 뗀 날짜
DateTime dayOf(DateTime d) => DateTime(d.year, d.month, d.day);

/// 그 주의 월요일
DateTime weekStartOf(DateTime d) {
  final day = dayOf(d);
  return DateTime(day.year, day.month, day.day - (day.weekday - 1));
}

/// 세션 여러 개를 합친 값 (하루, 한 주, 전체 누적에 공통으로 사용)
class SessionTotals {
  SessionTotals(this.sessions);

  final List<WorkoutSession> sessions;

  bool get isEmpty => sessions.isEmpty;
  int get sessionCount => sessions.length;
  int get setCount => sessions.fold<int>(0, (a, s) => a + s.setCount);
  int get totalReps => sessions.fold<int>(0, (a, s) => a + s.totalReps);
  int get goodReps => sessions.fold<int>(0, (a, s) => a + s.goodReps);
  int get totalSec => sessions.fold<int>(0, (a, s) => a + s.durationSec);
  double get caloriesKcal =>
      sessions.fold<double>(0, (a, s) => a + s.caloriesKcal);

  /// 정확도(%) = 정자세 횟수 합 ÷ 전체 횟수 합 × 100 (세션별 % 평균이 아님)
  double get accuracy => totalReps == 0 ? 0 : goodReps / totalReps * 100;

  /// 자세 점수: 반복 수로 가중 평균
  double get averageScore {
    if (totalReps == 0) return 0;
    final sum =
        sessions.fold<double>(0, (a, s) => a + s.averageScore * s.totalReps);
    return sum / totalReps;
  }

  /// 운동한 날 수
  int get activeDays => sessions.map((s) => dayOf(s.startedAt)).toSet().length;
}

/// 하루치
class DaySummary extends SessionTotals {
  DaySummary(this.date, super.sessions);
  final DateTime date;
}

/// 세션을 날짜별로 묶음 (하루 안에서는 시간순)
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

/// 7일치를 합친 주간 합계
SessionTotals weekTotals(List<DaySummary> days) =>
    SessionTotals(days.expand((d) => d.sessions).toList());

// ---------------- 표시용 글자 ----------------

const _weekdays = ['월', '화', '수', '목', '금', '토', '일'];

String weekdayKo(DateTime d) => _weekdays[d.weekday - 1];

String formatDateKo(DateTime d) => '${d.month}월 ${d.day}일 (${weekdayKo(d)})';

String formatTime(DateTime d) =>
    '${d.hour.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')}';

String formatDuration(int sec) {
  final h = sec ~/ 3600;
  final m = (sec % 3600) ~/ 60;
  final s = sec % 60;
  if (h > 0) return m == 0 ? '$h시간' : '$h시간 $m분';
  if (m == 0) return '$s초';
  return s == 0 ? '$m분' : '$m분 $s초';
}

String formatKcal(double kcal) =>
    kcal < 10 ? kcal.toStringAsFixed(1) : kcal.round().toString();

String formatWeekRange(DateTime weekStart) {
  final end = DateTime(weekStart.year, weekStart.month, weekStart.day + 6);
  return '${weekStart.month}.${weekStart.day} – ${end.month}.${end.day}';
}
