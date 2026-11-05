import '../models/workout_session.dart';

/// 운동 세션 목록으로부터 홈/기록/마이페이지의 통계를 계산합니다.
/// 저장소(Mock/DB/서버)와 무관한 순수 계산이라, 기록이 없으면 전부 0이 됩니다.
ActivitySummary buildActivitySummary(List<WorkoutSession> sessions, {DateTime? now}) {
  if (sessions.isEmpty) return ActivitySummary.empty;

  final today = _dayOnly(now ?? DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));
  final lastMonday = monday.subtract(const Duration(days: 7));

  final thisWeek = sessions.where((s) => !_dayOnly(s.date).isBefore(monday)).toList();
  final lastWeek = sessions.where((s) {
    final d = _dayOnly(s.date);
    return !d.isBefore(lastMonday) && d.isBefore(monday);
  }).toList();

  int reps(List<WorkoutSession> l) => l.fold(0, (a, s) => a + s.totalReps);
  double avgAccuracy(List<WorkoutSession> l) => l.isEmpty ? 0 : l.fold<double>(0, (a, s) => a + s.accuracy) / l.length;

  final thisAcc = avgAccuracy(thisWeek);
  final accDelta = (thisWeek.isEmpty || lastWeek.isEmpty) ? 0.0 : thisAcc - avgAccuracy(lastWeek);

  // 연속 운동 일수
  final days = sessions.map((s) => _dayOnly(s.date)).toSet().toList()..sort();
  var best = 1, run = 1;
  for (var i = 1; i < days.length; i++) {
    run = days[i].difference(days[i - 1]).inDays == 1 ? run + 1 : 1;
    if (run > best) best = run;
  }
  var streak = 0;
  var cursor = days.contains(today) ? today : today.subtract(const Duration(days: 1));
  while (days.contains(cursor)) {
    streak++;
    cursor = cursor.subtract(const Duration(days: 1));
  }

  return ActivitySummary(
    weeklyReps: reps(thisWeek),
    weeklyRepsDelta: reps(thisWeek) - reps(lastWeek),
    streakDays: streak,
    bestStreakDays: best,
    weeklyAccuracy: double.parse(thisAcc.toStringAsFixed(1)),
    weeklyAccuracyDelta: double.parse(accDelta.toStringAsFixed(1)),
    totalSessions: sessions.length,
    totalReps: reps(sessions),
    totalCalories: sessions.fold(0, (a, s) => a + s.calories),
  );
}

/// 이번 주 월~일 요일별 평균 정확도 (운동 안 한 날은 0)
List<DailyStat> buildWeeklyAccuracy(List<WorkoutSession> sessions, {DateTime? now}) {
  final today = _dayOnly(now ?? DateTime.now());
  final monday = today.subtract(Duration(days: today.weekday - 1));
  const labels = ['월', '화', '수', '목', '금', '토', '일'];
  return [
    for (var i = 0; i < 7; i++)
      () {
        final day = monday.add(Duration(days: i));
        final list = sessions.where((s) => _dayOnly(s.date) == day).toList();
        final avg = list.isEmpty ? 0.0 : list.fold<double>(0, (a, s) => a + s.accuracy) / list.length;
        return DailyStat(labels[i], avg);
      }(),
  ];
}

DateTime _dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);
