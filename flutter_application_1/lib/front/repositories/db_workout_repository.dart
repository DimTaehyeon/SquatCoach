import '../../db/app_database.dart';
import '../../models/workout_session.dart' as be; // 백엔드(DB)쪽 모델
import '../models/workout_session.dart';
import '../utils/activity_stats.dart';
import 'workout_repository.dart';

/// 백엔드의 SQLite(AppDatabase)에 저장된 운동 기록을 프론트 화면용 모델로 바꿔서 보여줍니다.
/// 기록 "저장"은 운동 컨트롤러(WorkoutController.finishAndSave)가 DB에 직접 하므로 여기선 읽기만 합니다.
class DbWorkoutRepository implements WorkoutRepository {
  final AppDatabase _db = AppDatabase.instance;

  Future<int> _userId() async => (await _db.getOrCreateDefaultUser()).id!;

  @override
  Future<List<WorkoutSession>> getRecentSessions() async {
    final rows = await _db.getSessionsByUser(await _userId());
    return rows.map(frontSessionFromDb).toList();
  }

  @override
  Future<WorkoutSession> getSessionById(String id) async {
    final detail = await _db.getSessionDetail(int.parse(id));
    if (detail == null) throw StateError('기록을 찾을 수 없어요 (id: $id)');
    return frontSessionFromDb(detail);
  }

  @override
  Future<void> saveSession(WorkoutSession session) async {
    // 저장은 WorkoutController.finishAndSave() 가 DB에 직접 합니다.
  }

  @override
  Future<List<DailyStat>> getWeeklyAccuracy() async => buildWeeklyAccuracy(await getRecentSessions());

  @override
  Future<ActivitySummary> getSummary() async => buildActivitySummary(await getRecentSessions());

  @override
  Future<void> clearAll() => _db.deleteAllWorkouts();
}

/// 백엔드 모델 → 프론트 화면용 모델
/// 정확도 = 정자세 횟수 ÷ 전체 횟수 (백엔드 기준 그대로)
WorkoutSession frontSessionFromDb(be.WorkoutSession s) {
  final memo = s.memo;
  return WorkoutSession(
    id: '${s.id}',
    date: s.startedAt,
    totalReps: s.totalReps,
    totalSets: s.setCount,
    accuracy: s.accuracy,
    durationSeconds: s.durationSec,
    calories: s.caloriesKcal.round(),
    feedbackNotes: (memo == null || memo.isEmpty || memo == '모든 반복 정자세') ? const [] : memo.split(' · '),
    setRecords: [for (final set in s.sets) frontSetFromDb(set)],
  );
}

SetRecord frontSetFromDb(be.WorkoutSet set) => SetRecord(
      setNumber: set.setIndex,
      reps: set.totalReps,
      accuracy: set.accuracy,
      durationSeconds: set.durationSec,
      note: set.faultCounts.isEmpty ? null : set.feedback,
    );
