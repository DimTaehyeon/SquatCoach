import 'dart:ui' show Size;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../ai/squat_classifier.dart';
import '../ai/squat_features.dart';
import '../ai/squat_rep_tracker.dart';
import '../ai/squat_rule_engine.dart';
import '../config/calories.dart';
import '../db/app_database.dart';
import '../models/workout_session.dart';

enum WorkoutPhase {
  calibrating, // 세트 시작 전 2초 영점 조절
  active, // 세트 진행 중 (횟수 세기·판정)
  resting, // 세트 끝, 다음 세트 대기
}

/// 운동 1번(세션)의 진행 상태. 화면(WorkoutPage)은 이 값을 보여주기만 함
///
/// 흐름: 영점 조절 → 세트 진행 → [세트 완료] → 휴식 → [다음 세트] → 영점 조절 …
///       → [운동 종료] → DB 저장 → 결과 화면
class WorkoutController {
  WorkoutController({required this.userId, required this.weightKg});

  final int userId;
  final double weightKg;

  final _calibrator = BaselineCalibrator();
  final _classifier = const SquatClassifier();
  final _ai = AiVoteCollector();
  RuleRepTracker? _tracker;

  WorkoutPhase phase = WorkoutPhase.calibrating;
  StandingBaseline? baseline;

  final List<WorkoutSet> sets = [];
  final List<RepRecord> currentReps = [];
  DateTime? _setStartedAt;

  RuleRepResult? lastRep;
  DateTime? lastRepAt;
  bool bodyVisible = false;

  // ---------------- 화면 표시용 ----------------

  int get setNumber => sets.length + 1;
  double calibrationProgress(DateTime now) => _calibrator.progress(now);
  String? get calibrationIssue => _calibrator.issue;
  bool get isDown => _tracker?.isDown ?? false;
  RuleRepTracker? get tracker => _tracker;
  List<double>? get aiProbs => _ai.lastProbs;

  int get currentGood => currentReps.where((r) => r.isGood).length;
  double get currentAccuracy =>
      currentReps.isEmpty ? 0 : currentGood / currentReps.length * 100;

  int get totalReps =>
      sets.fold<int>(0, (a, s) => a + s.totalReps) + currentReps.length;
  bool get hasAnyReps => totalReps > 0;

  // ---------------- 프레임 처리 ----------------

  /// 카메라 프레임마다 호출. 반복 1회가 끝난 프레임이면 true
  bool onFrame(Pose? pose, Size uprightSize, DateTime now) {
    final body = pose == null ? null : BodyPoints.fromPose(pose);
    bodyVisible = body != null;

    switch (phase) {
      case WorkoutPhase.resting:
        return false;

      case WorkoutPhase.calibrating:
        final b = _calibrator.add(body, now);
        if (b != null) {
          baseline = b;
          _tracker = RuleRepTracker(b);
          _ai.reset();
          phase = WorkoutPhase.active;
        }
        return false;

      case WorkoutPhase.active:
        final tracker = _tracker!;

        // AI 모델(참고): 앉아 있는 동안만
        if (pose != null && tracker.isDown) {
          final f = extractSquatFrame(pose, uprightSize);
          if (f != null) _ai.add(_classifier.predict(f.features));
        }

        final r = tracker.update(body, now);
        if (r == null) {
          if (!tracker.isDown) _ai.reset(); // 반복으로 인정되지 않은 움직임
          return false;
        }

        _setStartedAt ??= r.startedAt;
        currentReps.add(RepRecord(
          repIndex: currentReps.length + 1,
          endedAt: r.endedAt,
          isGood: r.isGood,
          faults: r.faults.map((f) => f.label).toList(),
          warnings: r.warnings.map((f) => f.label).toList(),
          score: r.score,
          aiLabel: _ai.majority?.label,
        ));
        _ai.reset();
        lastRep = r;
        lastRepAt = now;
        return true;
    }
  }

  // ---------------- 버튼 동작 ----------------

  /// 지금 세트를 끝내고 휴식으로. 반복이 하나도 없으면 영점부터 다시
  void completeSet() {
    if (currentReps.isEmpty) {
      restartCalibration();
      return;
    }
    sets.add(WorkoutSet.fromReps(
      setIndex: sets.length + 1,
      startedAt: _setStartedAt ?? currentReps.first.endedAt,
      endedAt: currentReps.last.endedAt,
      reps: List.of(currentReps),
    ));
    currentReps.clear();
    _setStartedAt = null;
    _tracker = null;
    lastRep = null;
    phase = WorkoutPhase.resting;
  }

  /// 다음 세트 시작 (판정 기준 문서: 세트 시작 전 2초 영점)
  void startNextSet() => restartCalibration();

  void restartCalibration() {
    _calibrator.reset();
    _tracker = null;
    _ai.reset();
    phase = WorkoutPhase.calibrating;
  }

  /// 운동 종료: 진행 중인 세트를 마무리하고 저장. 저장한 세션 id (기록이 없으면 null)
  Future<int?> finishAndSave() async {
    if (currentReps.isNotEmpty) completeSet();
    if (sets.isEmpty) return null;
    final activeSec = sets.fold<int>(0, (a, s) => a + s.durationSec);
    final session = WorkoutSession.fromSets(
      userId: userId,
      sets: sets,
      caloriesKcal: caloriesKcal(weightKg: weightKg, activeSeconds: activeSec),
    );
    final db = AppDatabase.instance;
    final id = await db.saveWorkout(session);

    // 저장 확인: DB에서 다시 읽어 값이 같은지 비교
    final saved = await db.getSessionDetail(id);
    final ok = saved != null &&
        saved.totalReps == session.totalReps &&
        saved.goodReps == session.goodReps &&
        saved.sets.length == session.sets.length &&
        saved.sets.fold<int>(0, (a, s) => a + s.reps.length) == session.totalReps;
    if (!ok) {
      await db.deleteSession(id); // 잘못 저장된 기록은 지우고 다시 시도하게 함
      throw StateError('저장 확인 실패 (세션 $id)');
    }
    return id;
  }
}
