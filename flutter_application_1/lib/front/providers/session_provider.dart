import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../config/squat_criteria.dart' show CheckRole, JudgeMode, SquatFault, kJudgeModeKey;
import '../../db/app_database.dart';
import '../../models/workout_session.dart' as be;
import '../../workout/workout_controller.dart';
import '../models/workout_session.dart';
import '../repositories/db_workout_repository.dart';

enum FeedbackLevel { warning, danger, good }

/// 결과 화면의 "자세교정 피드백" 카드 1개
class FeedbackItem {
  final String title;
  final String description;
  final FeedbackLevel level;
  const FeedbackItem(this.title, this.description, this.level);
}

/// 운동 설정(세트/횟수/휴식/판정 모드)과 진행 중인 운동을 화면들이 함께 보는 Provider.
///
/// 실제 판정·횟수 세기·저장은 백엔드의 [WorkoutController]가 하고,
/// 이 클래스는 그 상태를 화면(운동 분석 / 휴식 / 일시정지 / 결과)에 맞게 전달만 합니다.
class SessionProvider extends ChangeNotifier {
  SessionProvider() {
    _loadJudgeMode();
  }

  Timer? _ticker;

  // ---- 운동 설정 (운동 설정 화면에서 변경) ----
  String squatType = '맨몸';
  int totalSets = 3;
  int targetRepsPerSet = 15;
  int restSeconds = 60;
  int weightKg = 68; // 칼로리 계산용 (프로필에서 받아옴)
  JudgeMode judgeMode = JudgeMode.beginner;

  // ---- 진행 상태 ----
  WorkoutController? _controller;
  int _elapsedSeconds = 0; // 운동(세트 진행) 중인 시간만, 휴식·일시정지는 제외
  bool _paused = false;

  // ---- 끝난 뒤 (결과 화면용) ----
  WorkoutSession? _result;
  List<FeedbackItem> _feedback = const [];

  WorkoutController? get controller => _controller;
  bool get paused => _paused;
  bool get isFinished => _result != null;

  int get repsInSet => _controller?.currentReps.length ?? 0;
  int get currentGood => _controller?.currentGood ?? 0;

  /// 지금 세트 번호 (휴식 중이면 방금 끝난 세트 번호)
  int get currentSet {
    final c = _controller;
    if (c == null) return 1;
    return c.phase == WorkoutPhase.resting ? c.sets.length : c.setNumber;
  }

  /// 곧 시작할(또는 진행 중인) 세트 번호. 카운트다운 화면에서 사용
  int get upcomingSet {
    final c = _controller;
    if (c == null) return 1;
    return c.setNumber; // 휴식 중이면 sets.length + 1 = 다음 세트
  }

  /// 지금 세트의 정확도(%) = 정자세 횟수 ÷ 전체 횟수
  int get accuracy => (_controller?.currentAccuracy ?? 0).round();

  int get elapsedSeconds => _result?.durationSeconds ?? _elapsedSeconds;
  int get totalReps => _result?.totalReps ?? _controller?.totalReps ?? 0;
  bool get hasAnyReps => (_controller?.hasAnyReps ?? false);

  List<SetRecord> get setRecords =>
      _result?.setRecords ?? [for (final s in _controller?.sets ?? <be.WorkoutSet>[]) frontSetFromDb(s)];
  SetRecord? get lastSetRecord => setRecords.isEmpty ? null : setRecords.last;

  int get overallAccuracy => _result?.accuracy.round() ?? 0;
  int get calories => _result?.calories ?? 0;
  List<FeedbackItem> buildFeedbackItems() => _feedback;

  int get plannedTotalReps => totalSets * targetRepsPerSet;
  int get estimatedMinutes => ((plannedTotalReps * 5 + restSeconds * (totalSets - 1)) / 60).round();

  // ---------------- 설정 ----------------
  Future<void> _loadJudgeMode() async {
    try {
      judgeMode = JudgeMode.fromName(await AppDatabase.instance.getSetting(kJudgeModeKey));
      notifyListeners();
    } catch (_) {}
  }

  Future<void> setJudgeMode(JudgeMode mode) async {
    judgeMode = mode;
    notifyListeners();
    await AppDatabase.instance.setSetting(kJudgeModeKey, mode.name);
  }

  void updateSetup({String? squatType, int? sets, int? reps, int? rest}) {
    if (squatType != null) this.squatType = squatType;
    if (sets != null) totalSets = sets.clamp(1, 10).toInt();
    if (reps != null) targetRepsPerSet = reps.clamp(1, 50).toInt();
    if (rest != null) restSeconds = rest;
    notifyListeners();
  }

  // ---------------- 흐름 ----------------

  /// "측정 시작": 이전 운동을 비우고 새 운동(영점 조절부터)을 준비합니다.
  Future<void> startWorkout({required int weightKg}) async {
    reset();
    this.weightKg = weightKg;
    final user = await AppDatabase.instance.getOrCreateDefaultUser();
    _controller = WorkoutController(userId: user.id!, weightKg: weightKg.toDouble(), mode: judgeMode);
    _startTicker();
    notifyListeners();
  }

  /// 반복 1회가 끝났을 때 화면이 호출. 목표 횟수를 채워 세트가 끝났으면 true
  bool onRepCompleted() {
    final c = _controller;
    if (c == null) return false;
    notifyListeners();
    if (c.currentReps.length >= targetRepsPerSet) {
      completeSet();
      return true;
    }
    return false;
  }

  /// 세트 종료 (버튼 또는 목표 횟수 달성). 마지막 세트까지 끝났으면 true
  bool completeSet() {
    final c = _controller;
    if (c == null) return false;
    c.completeSet();
    _stopTicker();
    notifyListeners();
    return c.phase == WorkoutPhase.resting && c.sets.length >= totalSets;
  }

  bool get allSetsDone => (_controller?.sets.length ?? 0) >= totalSets;

  /// 휴식이 끝나고 다음 세트(영점 조절)를 시작
  void startNextSet() {
    _controller?.startNextSet();
    _paused = false;
    _startTicker();
    notifyListeners();
  }

  void pause() {
    if (_paused) return;
    _paused = true;
    _stopTicker();
    notifyListeners();
  }

  void resume() {
    if (!_paused) return;
    _paused = false;
    _startTicker();
    notifyListeners();
  }

  /// "이번 세트 다시 하기": 지금 세트 기록을 지우고 영점부터 다시
  void restartCurrentSet() {
    _controller?.discardCurrentSet();
    _paused = false;
    _startTicker();
    notifyListeners();
  }

  /// 운동 끝내기: 진행 중이던 세트까지 DB에 저장하고 결과를 만듭니다.
  /// 저장에 실패하면 예외를 던지고 기록은 그대로 남겨 둡니다 (다시 시도 가능).
  Future<void> finishAndSave() async {
    final c = _controller;
    if (c == null) return;
    _stopTicker();
    final id = await c.finishAndSave();
    if (id == null) {
      reset();
      notifyListeners();
      return;
    }
    final detail = await AppDatabase.instance.getSessionDetail(id);
    if (detail == null) throw StateError('저장한 기록을 다시 읽지 못했어요');
    _result = frontSessionFromDb(detail);
    _feedback = _buildFeedback(c.sets); // 저장 과정에서 진행 중이던 세트도 sets 에 들어감
    notifyListeners();
  }

  /// 아무것도 저장하지 않고 측정을 취소합니다.
  void cancel() {
    reset();
    notifyListeners();
  }

  // ---------------- 결과 ----------------

  /// 세트들의 반복 기록을 모아 "오류 / 참고" 항목별 횟수를 피드백 카드로 만듭니다.
  List<FeedbackItem> _buildFeedback(List<be.WorkoutSet> sets) {
    final errors = <String, int>{};
    final warnings = <String, int>{};
    for (final s in sets) {
      for (final r in s.reps) {
        if (!r.isGood) {
          for (final f in r.faults) {
            errors[f] = (errors[f] ?? 0) + 1;
          }
        }
        for (final w in r.warnings) {
          warnings[w] = (warnings[w] ?? 0) + 1;
        }
      }
    }

    String advice(String label) {
      for (final f in SquatFault.values) {
        if (f.label == label) return f.feedback;
      }
      return '';
    }

    final items = <FeedbackItem>[];
    final sortedErrors = errors.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
    for (final e in sortedErrors) {
      items.add(FeedbackItem('${e.key} (${e.value}회 감지)', advice(e.key), FeedbackLevel.danger));
    }
    final sortedWarnings = warnings.entries.where((w) => !errors.containsKey(w.key)).toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    for (final w in sortedWarnings) {
      final isReference = SquatFault.values.any((f) => f.label == w.key && f.role == CheckRole.reference);
      items.add(FeedbackItem(
        '${w.key} (${w.value}회${isReference ? ' · 참고' : ''})',
        advice(w.key),
        FeedbackLevel.warning,
      ));
    }
    if (items.isEmpty) {
      items.add(const FeedbackItem(
        '모든 반복이 정자세였어요',
        '다리 모양, 앉는 깊이, 몸 균형이 모두 좋았어요. 이 감각을 유지해주세요.',
        FeedbackLevel.good,
      ));
    }
    return items;
  }

  /// 결과 화면을 닫을 때 호출해 측정 상태를 비웁니다. (설정은 유지)
  void reset() {
    _stopTicker();
    _controller = null;
    _elapsedSeconds = 0;
    _paused = false;
    _result = null;
    _feedback = const [];
  }

  void _startTicker() {
    _ticker?.cancel();
    _ticker = Timer.periodic(const Duration(seconds: 1), (_) {
      _elapsedSeconds += 1;
      notifyListeners();
    });
  }

  void _stopTicker() {
    _ticker?.cancel();
    _ticker = null;
  }

  @override
  void dispose() {
    _stopTicker();
    super.dispose();
  }
}
