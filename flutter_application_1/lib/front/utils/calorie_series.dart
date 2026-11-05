import '../models/workout_session.dart';
import '../repositories/workout_repository.dart';

/// 칼로리 활동 화면에 필요한 값: 막대 그래프 데이터 + 같은 기간의 총 스쿼트 횟수.
class CalorieReport {
  const CalorieReport(this.bars, this.totalReps);

  final List<DailyStat> bars; // value = kcal
  final int totalReps;

  int get totalKcal => bars.fold<double>(0, (a, b) => a + b.value).round();
}

/// 운동 세션 목록(WorkoutSession.calories)을 기간별로 합산합니다.
/// 저장소(Mock/DB/서버)와 무관한 순수 계산이라 어떤 저장소를 써도 그대로 동작해요.
///
/// - 일간: 오늘 세션을 시간대(6·9·12·15·18·21시)로 묶음
/// - 주간: 이번 주 월~일
/// - 월간: 이번 달 1~4주 (1~7일, 8~14일, 15~21일, 22일~말일)
CalorieReport buildCalorieReport(List<WorkoutSession> sessions, CalorieRange range, {DateTime? now}) {
  final today = now ?? DateTime.now();
  final day0 = DateTime(today.year, today.month, today.day);

  bool sameDay(DateTime a, DateTime b) => a.year == b.year && a.month == b.month && a.day == b.day;

  late final List<String> labels;
  late final int Function(WorkoutSession) bucket; // 해당 세션이 속한 막대 번호 (-1이면 기간 밖)

  switch (range) {
    case CalorieRange.daily:
      labels = ['6시', '9시', '12시', '15시', '18시', '21시'];
      bucket = (s) {
        if (!sameDay(s.date, day0)) return -1;
        final h = s.date.hour;
        if (h < 9) return 0;
        if (h < 12) return 1;
        if (h < 15) return 2;
        if (h < 18) return 3;
        if (h < 21) return 4;
        return 5;
      };
    case CalorieRange.weekly:
      labels = ['월', '화', '수', '목', '금', '토', '일'];
      final monday = day0.subtract(Duration(days: day0.weekday - 1));
      bucket = (s) {
        final d = DateTime(s.date.year, s.date.month, s.date.day);
        final diff = d.difference(monday).inDays;
        return diff >= 0 && diff < 7 ? diff : -1;
      };
    case CalorieRange.monthly:
      labels = ['1주', '2주', '3주', '4주'];
      bucket = (s) {
        if (s.date.year != day0.year || s.date.month != day0.month) return -1;
        return ((s.date.day - 1) ~/ 7).clamp(0, 3).toInt();
      };
  }

  final kcal = List<double>.filled(labels.length, 0);
  var reps = 0;
  for (final s in sessions) {
    final i = bucket(s);
    if (i < 0) continue;
    kcal[i] += s.calories;
    reps += s.totalReps;
  }
  return CalorieReport([for (var i = 0; i < labels.length; i++) DailyStat(labels[i], kcal[i])], reps);
}
