import '../models/workout_session.dart';

/// 운동 기록을 가져오고 저장하는 "약속"(인터페이스)입니다.
/// 지금은 [MockWorkoutRepository]만 있지만, 나중에 DB/서버가 정해지면
/// 이 인터페이스를 구현한 RealWorkoutRepository를 추가하고
/// main.dart에서 주입하는 한 줄만 바꾸면 화면 코드는 전혀 안 건드려도 됩니다.
/// 칼로리 활동 화면의 기간 탭 (일간/주간/월간)
enum CalorieRange { daily, weekly, monthly }

abstract class WorkoutRepository {
  Future<List<WorkoutSession>> getRecentSessions();
  Future<WorkoutSession> getSessionById(String id);
  Future<void> saveSession(WorkoutSession session);
  Future<List<DailyStat>> getWeeklyAccuracy();
  Future<ActivitySummary> getSummary();

  /// 모든 운동 기록을 지웁니다. (처음 상태로 되돌릴 때)
  Future<void> clearAll();
}
