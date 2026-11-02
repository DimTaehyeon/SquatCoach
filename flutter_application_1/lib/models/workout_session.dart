import 'dart:convert';

/// 운동 1번(세션). 세트 여러 개로 이루어짐
///
/// 횟수·정확도·시간·칼로리는 세트 값을 합친 결과를 저장해 둡니다.
/// (기록 목록과 그래프를 빠르게 그리기 위해)
class WorkoutSession {
  final int? id;
  final int userId;
  final String exerciseType; // 'squat'
  final DateTime startedAt;
  final int durationSec; // 첫 세트 시작 ~ 마지막 세트 끝 (휴식 포함)
  final int totalReps;
  final int goodReps; // 정자세 횟수
  final double averageScore; // 반복별 자세 점수(0~100)의 평균
  final double caloriesKcal;
  final String? memo; // 자세 피드백 요약 (예: "깊이 부족 2회 · 다리 모아짐 1회")
  final List<WorkoutSet> sets; // 상세 조회 때만 채워짐
  final int storedSetCount; // 목록 조회 때 DB가 세어 준 세트 수

  const WorkoutSession({
    this.id,
    required this.userId,
    required this.exerciseType,
    required this.startedAt,
    required this.durationSec,
    required this.totalReps,
    required this.goodReps,
    required this.averageScore,
    this.caloriesKcal = 0,
    this.memo,
    this.sets = const [],
    this.storedSetCount = 0,
  });

  /// 정확도(%) = 정자세 횟수 ÷ 전체 횟수 × 100
  double get accuracy => totalReps == 0 ? 0 : goodReps / totalReps * 100;

  int get setCount => sets.isNotEmpty ? sets.length : storedSetCount;

  Map<String, Object?> toMap() => {
        'id': id,
        'user_id': userId,
        'exercise_type': exerciseType,
        'started_at': startedAt.toIso8601String(),
        'duration_sec': durationSec,
        'total_reps': totalReps,
        'good_reps': goodReps,
        'average_score': averageScore,
        'calories_kcal': caloriesKcal,
        'memo': memo,
      };

  factory WorkoutSession.fromMap(Map<String, Object?> map,
          {List<WorkoutSet> sets = const []}) =>
      WorkoutSession(
        id: map['id'] as int,
        userId: map['user_id'] as int,
        exerciseType: map['exercise_type'] as String,
        startedAt: DateTime.parse(map['started_at'] as String),
        durationSec: map['duration_sec'] as int,
        totalReps: map['total_reps'] as int,
        goodReps: map['good_reps'] as int,
        averageScore: (map['average_score'] as num).toDouble(),
        caloriesKcal: (map['calories_kcal'] as num?)?.toDouble() ?? 0,
        memo: map['memo'] as String?,
        sets: sets,
        storedSetCount: (map['set_count'] as int?) ?? sets.length,
      );

  WorkoutSession copyWith({int? id, List<WorkoutSet>? sets}) => WorkoutSession(
        id: id ?? this.id,
        userId: userId,
        exerciseType: exerciseType,
        startedAt: startedAt,
        durationSec: durationSec,
        totalReps: totalReps,
        goodReps: goodReps,
        averageScore: averageScore,
        caloriesKcal: caloriesKcal,
        memo: memo,
        sets: sets ?? this.sets,
        storedSetCount: storedSetCount,
      );

  /// 세트들을 합쳐서 세션 하나를 만듦
  factory WorkoutSession.fromSets({
    required int userId,
    required List<WorkoutSet> sets,
    required double caloriesKcal,
    String exerciseType = 'squat',
  }) {
    assert(sets.isNotEmpty);
    final start = sets.first.startedAt;
    final lastEnd = sets.last.startedAt.add(Duration(seconds: sets.last.durationSec));
    final total = sets.fold<int>(0, (a, s) => a + s.totalReps);
    final good = sets.fold<int>(0, (a, s) => a + s.goodReps);
    final scoreSum = sets.fold<double>(0, (a, s) => a + s.averageScore * s.totalReps);
    final faults = <String, int>{};
    for (final s in sets) {
      s.faultCounts.forEach((k, v) => faults[k] = (faults[k] ?? 0) + v);
    }
    final duration = lastEnd.difference(start).inSeconds;
    return WorkoutSession(
      userId: userId,
      exerciseType: exerciseType,
      startedAt: start,
      durationSec: duration < 1 ? 1 : duration,
      totalReps: total,
      goodReps: good,
      averageScore: total == 0 ? 0 : scoreSum / total,
      caloriesKcal: caloriesKcal,
      memo: faultSummary(faults),
      sets: sets,
    );
  }

  @override
  String toString() =>
      'WorkoutSession(id: $id, user: $userId, ${sets.length}세트, $totalReps회 중 $goodReps회 정자세)';
}

/// 세트 1개
class WorkoutSet {
  final int? id;
  final int? sessionId;
  final int setIndex; // 1부터
  final DateTime startedAt;
  final int durationSec;
  final int totalReps;
  final int goodReps;
  final double averageScore;
  final Map<String, int> faultCounts; // 오류 이름 → 횟수 (예: {'깊이 부족': 2})
  final List<RepRecord> reps;

  const WorkoutSet({
    this.id,
    this.sessionId,
    required this.setIndex,
    required this.startedAt,
    required this.durationSec,
    required this.totalReps,
    required this.goodReps,
    required this.averageScore,
    this.faultCounts = const {},
    this.reps = const [],
  });

  double get accuracy => totalReps == 0 ? 0 : goodReps / totalReps * 100;
  String get feedback => faultSummary(faultCounts);

  Map<String, Object?> toMap(int sessionId) => {
        'id': id,
        'session_id': sessionId,
        'set_index': setIndex,
        'started_at': startedAt.toIso8601String(),
        'duration_sec': durationSec,
        'total_reps': totalReps,
        'good_reps': goodReps,
        'average_score': averageScore,
        'fault_counts': jsonEncode(faultCounts),
      };

  factory WorkoutSet.fromMap(Map<String, Object?> map,
      {List<RepRecord> reps = const []}) {
    final raw = map['fault_counts'] as String?;
    final decoded = raw == null || raw.isEmpty
        ? <String, dynamic>{}
        : jsonDecode(raw) as Map<String, dynamic>;
    return WorkoutSet(
      id: map['id'] as int,
      sessionId: map['session_id'] as int,
      setIndex: map['set_index'] as int,
      startedAt: DateTime.parse(map['started_at'] as String),
      durationSec: map['duration_sec'] as int,
      totalReps: map['total_reps'] as int,
      goodReps: map['good_reps'] as int,
      averageScore: (map['average_score'] as num).toDouble(),
      faultCounts: decoded.map((k, v) => MapEntry(k, (v as num).toInt())),
      reps: reps,
    );
  }

  /// 반복 결과들로 세트 하나를 만듦
  factory WorkoutSet.fromReps({
    required int setIndex,
    required DateTime startedAt,
    required DateTime endedAt,
    required List<RepRecord> reps,
  }) {
    final faults = <String, int>{};
    for (final r in reps.where((r) => !r.isGood)) {
      for (final f in r.faults) {
        faults[f] = (faults[f] ?? 0) + 1;
      }
    }
    final duration = endedAt.difference(startedAt).inSeconds;
    return WorkoutSet(
      setIndex: setIndex,
      startedAt: startedAt,
      durationSec: duration < 1 ? 1 : duration,
      totalReps: reps.length,
      goodReps: reps.where((r) => r.isGood).length,
      averageScore: reps.isEmpty
          ? 0
          : reps.fold<double>(0, (a, r) => a + r.score) / reps.length,
      faultCounts: faults,
      reps: reps,
    );
  }
}

/// 반복 1회 기록 (판정 검증용으로도 사용)
class RepRecord {
  final int? id;
  final int repIndex; // 1부터
  final DateTime endedAt;
  final bool isGood;
  final List<String> faults; // 오류 판정된 항목 (판정 대상 기준)
  final List<String> warnings; // 주의/참고 항목
  final double score; // 0~100
  final String? aiLabel; // 모델이 가장 많이 낸 판정 (참고)

  const RepRecord({
    this.id,
    required this.repIndex,
    required this.endedAt,
    required this.isGood,
    this.faults = const [],
    this.warnings = const [],
    required this.score,
    this.aiLabel,
  });

  Map<String, Object?> toMap(int setId) => {
        'id': id,
        'set_id': setId,
        'rep_index': repIndex,
        'ended_at': endedAt.toIso8601String(),
        'is_good': isGood ? 1 : 0,
        'faults': faults.join('|'),
        'warnings': warnings.join('|'),
        'score': score,
        'ai_label': aiLabel,
      };

  factory RepRecord.fromMap(Map<String, Object?> map) {
    List<String> split(Object? v) {
      final s = v as String?;
      return s == null || s.isEmpty ? const [] : s.split('|');
    }

    return RepRecord(
      id: map['id'] as int,
      repIndex: map['rep_index'] as int,
      endedAt: DateTime.parse(map['ended_at'] as String),
      isGood: (map['is_good'] as int) == 1,
      faults: split(map['faults']),
      warnings: split(map['warnings']),
      score: (map['score'] as num).toDouble(),
      aiLabel: map['ai_label'] as String?,
    );
  }
}

/// {'깊이 부족': 2, '다리 모아짐': 1} → "깊이 부족 2회 · 다리 모아짐 1회"
String faultSummary(Map<String, int> counts) {
  if (counts.isEmpty) return '모든 반복 정자세';
  final sorted = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return sorted.map((e) => '${e.key} ${e.value}회').join(' · ');
}
