/// 운동 세션 1회 기록 (예: 스쿼트 한 세트)
class WorkoutSession {
  final int? id;
  final int userId; // 어떤 사용자의 기록인지 (users.id)
  final String exerciseType; // 'squat' 등
  final DateTime startedAt;
  final int durationSec; // 운동한 시간(초)
  final int totalReps; // 전체 횟수
  final int goodReps; // 올바른 자세로 한 횟수
  final double averageScore; // 자세 점수 평균 (0~100)
  final String? memo;

  const WorkoutSession({
    this.id,
    required this.userId,
    required this.exerciseType,
    required this.startedAt,
    required this.durationSec,
    required this.totalReps,
    required this.goodReps,
    required this.averageScore,
    this.memo,
  });

  /// 정확도(%) = 올바른 횟수 / 전체 횟수
  double get accuracy => totalReps == 0 ? 0 : goodReps / totalReps * 100;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'exercise_type': exerciseType,
        'started_at': startedAt.toIso8601String(),
        'duration_sec': durationSec,
        'total_reps': totalReps,
        'good_reps': goodReps,
        'average_score': averageScore,
        'memo': memo,
      };

  factory WorkoutSession.fromMap(Map<String, Object?> map) => WorkoutSession(
        id: map['id'] as int,
        userId: map['user_id'] as int,
        exerciseType: map['exercise_type'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        durationSec: map['duration_sec'] as int,
        totalReps: map['total_reps'] as int,
        goodReps: map['good_reps'] as int,
        averageScore: (map['average_score'] as num).toDouble(),
        memo: map['memo'] as String?,
      );

  @override
  String toString() =>
      'WorkoutSession(id: $id, user: $userId, $exerciseType, '
      '$totalReps회 중 $goodReps회 정확, 점수 ${averageScore.toStringAsFixed(1)})';
}
