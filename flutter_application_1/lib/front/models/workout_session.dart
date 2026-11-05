import '../utils/format.dart';

/// 한 세트의 기록 (세션 상세의 "세트별 기록")
class SetRecord {
  final int setNumber;
  final int reps;
  final double accuracy; // 0~100
  final int durationSeconds;
  final String? note; // 예: "후반 피로 감지"

  const SetRecord({
    required this.setNumber,
    required this.reps,
    required this.accuracy,
    required this.durationSeconds,
    this.note,
  });

  String get formattedDuration => minSecKo(durationSeconds);

  Map<String, dynamic> toJson() => {
        'setNumber': setNumber,
        'reps': reps,
        'accuracy': accuracy,
        'durationSeconds': durationSeconds,
        'note': note,
      };

  factory SetRecord.fromJson(Map<String, dynamic> j) => SetRecord(
        setNumber: (j['setNumber'] as num).toInt(),
        reps: (j['reps'] as num).toInt(),
        accuracy: (j['accuracy'] as num).toDouble(),
        durationSeconds: (j['durationSeconds'] as num).toInt(),
        note: j['note'] as String?,
      );
}

/// 운동 1세션(한 번 운동한 기록)을 나타내는 모델.
/// 기기 저장소에는 toJson/fromJson으로 저장/복원합니다.
class WorkoutSession {
  final String id;
  final DateTime date;
  final int totalReps;
  final int totalSets;
  final double accuracy; // 0~100
  final int durationSeconds;
  final int calories;
  final List<String> feedbackNotes;
  final List<SetRecord> setRecords;

  const WorkoutSession({
    required this.id,
    required this.date,
    required this.totalReps,
    required this.totalSets,
    required this.accuracy,
    required this.durationSeconds,
    required this.calories,
    this.feedbackNotes = const [],
    this.setRecords = const [],
  });

  String get formattedDuration => mmss(durationSeconds);

  /// 기기 저장소(shared_preferences)에 넣기 위한 JSON 변환
  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date.toIso8601String(),
        'totalReps': totalReps,
        'totalSets': totalSets,
        'accuracy': accuracy,
        'durationSeconds': durationSeconds,
        'calories': calories,
        'feedbackNotes': feedbackNotes,
        'setRecords': [for (final r in setRecords) r.toJson()],
      };

  factory WorkoutSession.fromJson(Map<String, dynamic> j) => WorkoutSession(
        id: j['id'] as String,
        date: DateTime.parse(j['date'] as String),
        totalReps: (j['totalReps'] as num).toInt(),
        totalSets: (j['totalSets'] as num).toInt(),
        accuracy: (j['accuracy'] as num).toDouble(),
        durationSeconds: (j['durationSeconds'] as num).toInt(),
        calories: (j['calories'] as num).toInt(),
        feedbackNotes: [for (final n in (j['feedbackNotes'] as List? ?? const [])) n as String],
        setRecords: [
          for (final r in (j['setRecords'] as List? ?? const [])) SetRecord.fromJson(r as Map<String, dynamic>),
        ],
      );
}

/// 요일별 정확도 등을 담는 간단한 통계 포인트 (그래프용).
class DailyStat {
  final String label; // 월, 화, 수 ...
  final double value;
  const DailyStat(this.label, this.value);
}

/// 홈/기록/마이페이지에 쓰이는 집계 통계.
/// 나중에 백엔드가 생기면 서버가 계산해서 내려주거나, 앱이 세션 목록으로 직접 계산해도 됩니다.
class ActivitySummary {
  final int weeklyReps; // 이번 주 스쿼트 횟수
  final int weeklyRepsDelta; // 지난주 대비 증감
  final int streakDays; // 현재 연속 운동 일수
  final int bestStreakDays; // 최장 연속 기록
  final double weeklyAccuracy; // 이번 주 평균 정확도
  final double weeklyAccuracyDelta; // 지난주 대비 %p
  final int totalSessions;
  final int totalReps;
  final int totalCalories;

  const ActivitySummary({
    required this.weeklyReps,
    required this.weeklyRepsDelta,
    required this.streakDays,
    required this.bestStreakDays,
    required this.weeklyAccuracy,
    required this.weeklyAccuracyDelta,
    required this.totalSessions,
    required this.totalReps,
    required this.totalCalories,
  });

  static const empty = ActivitySummary(
    weeklyReps: 0,
    weeklyRepsDelta: 0,
    streakDays: 0,
    bestStreakDays: 0,
    weeklyAccuracy: 0,
    weeklyAccuracyDelta: 0,
    totalSessions: 0,
    totalReps: 0,
    totalCalories: 0,
  );
}
