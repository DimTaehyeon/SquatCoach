import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../config/squat_criteria.dart' as c;
import '../config/squat_criteria.dart' show Level, SquatFault, CheckRole, Threshold;

/// 판정 기준 문서(v0.2)를 그대로 옮긴 규칙 판정
///
/// 좌표는 ML Kit 픽셀 좌표(화면에 보이는 방향)를 그대로 씀. 모든 값이 비율이라
/// 해상도·거리에 영향을 덜 받음.

class _P {
  const _P(this.x, this.y);
  final double x, y;
  double dist(_P o) => math.sqrt(math.pow(x - o.x, 2) + math.pow(y - o.y, 2));
  _P mid(_P o) => _P((x + o.x) / 2, (y + o.y) / 2);
}

/// 한 프레임에서 뽑은 관절 위치 (인식률이 낮으면 null)
class BodyPoints {
  BodyPoints._(this._pts);
  final Map<PoseLandmarkType, _P> _pts;

  static const requiredTypes = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
    PoseLandmarkType.leftKnee,
    PoseLandmarkType.rightKnee,
    PoseLandmarkType.leftAnkle,
    PoseLandmarkType.rightAnkle,
  ];

  /// 필수 관절 중 하나라도 인식률이 기준 미만이면 null → 이 프레임은 판정에서 제외
  static BodyPoints? fromPose(Pose pose) {
    final pts = <PoseLandmarkType, _P>{};
    for (final t in requiredTypes) {
      final lm = pose.landmarks[t];
      if (lm == null || lm.likelihood < c.minVisibility) return null;
      pts[t] = _P(lm.x, lm.y);
    }
    for (final t in [PoseLandmarkType.leftHeel, PoseLandmarkType.rightHeel]) {
      final lm = pose.landmarks[t];
      if (lm != null && lm.likelihood >= c.minVisibility) pts[t] = _P(lm.x, lm.y);
    }
    return BodyPoints._(pts);
  }

  _P _at(PoseLandmarkType t) => _pts[t]!;

  _P get ls => _at(PoseLandmarkType.leftShoulder);
  _P get rs => _at(PoseLandmarkType.rightShoulder);
  _P get lh => _at(PoseLandmarkType.leftHip);
  _P get rh => _at(PoseLandmarkType.rightHip);
  _P get lk => _at(PoseLandmarkType.leftKnee);
  _P get rk => _at(PoseLandmarkType.rightKnee);
  _P get la => _at(PoseLandmarkType.leftAnkle);
  _P get ra => _at(PoseLandmarkType.rightAnkle);

  _P get hipMid => lh.mid(rh);
  _P get shoulderMid => ls.mid(rs);
  double get thigh => (lh.dist(lk) + rh.dist(rk)) / 2;
  double get shin => (lk.dist(la) + rk.dist(ra)) / 2;
  double get torsoHeight => (hipMid.y - shoulderMid.y).abs();
  double get ankleWidth => (la.x - ra.x).abs();
  double get kneeWidth => (lk.x - rk.x).abs();
  double get shoulderWidth => (ls.x - rs.x).abs();

  /// 뒤꿈치 높이 (안 보이면 null)
  double? get heelY {
    final l = _pts[PoseLandmarkType.leftHeel];
    final r = _pts[PoseLandmarkType.rightHeel];
    if (l == null && r == null) return null;
    if (l == null) return r!.y;
    if (r == null) return l.y;
    return (l.y + r.y) / 2;
  }
}

// ───────────────────────── 서 있을 때 값 (영점) ─────────────────────────

class StandingBaseline {
  const StandingBaseline({
    required this.thigh,
    required this.shin,
    required this.torso,
    required this.ankleWidth,
    required this.shoulderWidth,
    required this.hipMidX,
    required this.hipMidY,
    required this.heelY,
  });

  final double thigh, shin, torso, ankleWidth, shoulderWidth;
  final double hipMidX, hipMidY;
  final double? heelY;

  /// 다리 벌어짐(보폭) — 준비 자세에서 한 번 확인 (참고)
  Level get stanceLevel {
    if (shoulderWidth <= 0) return Level.ok;
    final r = ankleWidth / shoulderWidth;
    if (r > c.stanceTooWide.error || r < c.stanceTooNarrow.error) return Level.error;
    if (r > c.stanceTooWide.warning || r < c.stanceTooNarrow.warning) {
      return Level.warning;
    }
    return Level.ok;
  }
}

/// 세트 시작 전 [c.calibrationDuration] 동안 가만히 서 있는 모습으로 영점을 잡음
class BaselineCalibrator {
  final List<BodyPoints> _frames = [];
  DateTime? _start;

  /// 영점을 못 잡는 이유 (화면 안내용). null이면 진행 중
  String? issue;

  /// 0~1 진행률
  double progress(DateTime now) {
    if (_start == null) return 0;
    final p = now.difference(_start!).inMilliseconds /
        c.calibrationDuration.inMilliseconds;
    return p.clamp(0.0, 1.0).toDouble();
  }

  void reset() {
    _frames.clear();
    _start = null;
  }

  /// 프레임 추가. 영점이 완성되면 결과를 돌려줌
  StandingBaseline? add(BodyPoints? body, DateTime now) {
    if (body == null) {
      reset(); // 전신이 안 보이면 처음부터
      issue = '머리부터 발끝까지 화면에 들어오게 서 주세요';
      return null;
    }
    if (body.shoulderWidth < body.thigh * c.minFrontalShoulderToThigh) {
      reset();
      issue = '카메라를 정면으로 바라보고 서 주세요';
      return null;
    }
    issue = null;
    // 움직이면 처음부터 (엉덩이가 허벅지 길이의 8% 넘게 움직임)
    if (_frames.isNotEmpty) {
      final first = _frames.first;
      final moved = (body.hipMid.y - first.hipMid.y).abs() / first.thigh;
      if (moved > 0.08) {
        reset();
        issue = '움직이지 말고 똑바로 서 주세요';
      }
    }
    _start ??= now;
    _frames.add(body);
    if (now.difference(_start!) < c.calibrationDuration || _frames.length < 5) {
      return null;
    }

    double avg(double Function(BodyPoints) f) =>
        _frames.map(f).reduce((a, b) => a + b) / _frames.length;
    final heels = _frames.map((f) => f.heelY).whereType<double>().toList();
    final baseline = StandingBaseline(
      thigh: avg((f) => f.thigh),
      shin: avg((f) => f.shin),
      torso: avg((f) => f.torsoHeight),
      ankleWidth: avg((f) => f.ankleWidth),
      shoulderWidth: avg((f) => f.shoulderWidth),
      hipMidX: avg((f) => f.hipMid.x),
      hipMidY: avg((f) => f.hipMid.y),
      heelY: heels.length >= _frames.length / 2
          ? heels.reduce((a, b) => a + b) / heels.length
          : null,
    );
    reset();
    return baseline;
  }
}

// ───────────────────────── 프레임별 측정값 ─────────────────────────

class FrameMetrics {
  FrameMetrics(StandingBaseline b, BodyPoints p, this.time)
      : hipDrop = (p.hipMid.y - b.hipMidY) / b.thigh,
        kneeRatio = p.ankleWidth > 0 ? p.kneeWidth / p.ankleWidth : 1.0,
        shoulderTiltDeg = math.atan2((p.ls.y - p.rs.y).abs(),
                (p.ls.x - p.rs.x).abs().clamp(1e-6, double.infinity)) *
            180 /
            math.pi,
        pelvisTilt = (p.lh.y - p.rh.y).abs() / b.thigh,
        pelvisShift =
            b.ankleWidth > 0 ? (p.hipMid.x - b.hipMidX).abs() / b.ankleWidth : 0.0,
        torsoRatio = b.torso > 0 ? p.torsoHeight / b.torso : 1.0,
        heelRise = (b.heelY != null && p.heelY != null)
            ? (b.heelY! - p.heelY!) / b.shin
            : null;

  final DateTime time;
  final double hipDrop; // 엉덩이가 내려간 높이 ÷ 허벅지 길이 (클수록 깊이 앉음)
  final double kneeRatio; // 무릎 간격 ÷ 발목 간격
  final double shoulderTiltDeg;
  final double pelvisTilt;
  final double pelvisShift;
  final double torsoRatio; // 상체 세로 길이 ÷ 서 있을 때 상체 길이
  final double? heelRise;

  /// 작을수록 나쁜 값
  static Level below(double v, Threshold t) =>
      v < t.error ? Level.error : (v < t.warning ? Level.warning : Level.ok);

  /// 클수록 나쁜 값
  static Level above(double v, Threshold t) =>
      v > t.error ? Level.error : (v > t.warning ? Level.warning : Level.ok);

  Level get kneeCaving => below(kneeRatio, c.kneeCavingRatio);

  /// 몸이 좌우로 기울어짐: 3개 지표 중 가장 나쁜 단계
  Level get lateralTilt => _worst([
        above(shoulderTiltDeg, c.shoulderTiltDeg),
        above(pelvisTilt, c.pelvisTiltRatio),
        above(pelvisShift, c.pelvisShiftRatio),
      ]);

  Level get forwardLean => below(torsoRatio, c.forwardLeanRatio);

  Level get heel => heelRise == null ? Level.ok : above(heelRise!, c.heelRaiseRatio);
}

Level _worst(Iterable<Level> levels) =>
    levels.fold(Level.ok, (a, b) => a.index >= b.index ? a : b);

/// 연속 [n]프레임 이상 오류면 오류, 연속 [n]프레임 이상 주의 이상이면 주의
Level sustainedLevel(List<Level> levels, {int n = c.consecutiveFrames}) {
  final need = math.min(n, levels.length);
  if (need == 0) return Level.ok;
  int longest(bool Function(Level) hit) {
    var best = 0, run = 0;
    for (final l in levels) {
      run = hit(l) ? run + 1 : 0;
      if (run > best) best = run;
    }
    return best;
  }

  if (longest((l) => l == Level.error) >= need) return Level.error;
  if (longest((l) => l != Level.ok) >= need) return Level.warning;
  return Level.ok;
}

// ───────────────────────── 반복 1회 판정 ─────────────────────────

class RuleRepResult {
  RuleRepResult({
    required this.levels,
    required this.depthRatio,
    required this.startedAt,
    required this.endedAt,
  });

  final Map<SquatFault, Level> levels;
  final double depthRatio; // 최저점 깊이 (엉덩이 하강 ÷ 허벅지 길이)
  final DateTime startedAt;
  final DateTime endedAt;

  /// 판정 규칙: 판정 대상 중 하나라도 '오류'면 그 1회는 오류
  bool get isGood => !levels.entries
      .any((e) => e.key.role == CheckRole.judged && e.value == Level.error);

  List<SquatFault> get faults => [
        for (final e in levels.entries)
          if (e.key.role == CheckRole.judged && e.value == Level.error) e.key,
      ];

  /// 판정 대상의 '주의' + 참고 항목의 주의/오류
  List<SquatFault> get warnings => [
        for (final e in levels.entries)
          if ((e.key.role == CheckRole.judged && e.value == Level.warning) ||
              (e.key.role == CheckRole.reference && e.value != Level.ok))
            e.key,
      ];

  /// 0~100점: 판정 대상 오류 -25, 주의 -10 / 참고 오류 -10, 주의 -5
  double get score {
    var s = 100.0;
    levels.forEach((f, l) {
      if (l == Level.ok) return;
      final judged = f.role == CheckRole.judged;
      s -= l == Level.error ? (judged ? 25 : 10) : (judged ? 10 : 5);
    });
    return s.clamp(0, 100).toDouble();
  }
}

/// 엉덩이 높이로 앉았다 일어서는 것을 구분하고, 그 사이의 프레임으로 1회를 판정
class RuleRepTracker {
  RuleRepTracker(this.baseline);

  final StandingBaseline baseline;
  final List<FrameMetrics> _frames = [];
  bool _isDown = false;

  /// 실시간 피드백용: 항목별 연속 프레임 수
  final Map<SquatFault, int> _liveRun = {};

  bool get isDown => _isDown;

  /// 지금 화면에 띄울 피드백 (연속 3프레임 이상 걸린 것 중 가장 중요한 것)
  SquatFault? liveFault;
  Level liveLevel = Level.ok;

  double _top = double.infinity; // 직전에 서 있던 높이 (hipDrop 최솟값)
  double _peak = 0; // 이번 반복에서 가장 깊이 내려간 값

  // 중복 카운트 방지
  final List<double> _recentDrops = []; // 최근 엉덩이 높이 (관절 떨림을 줄이려고 중앙값 사용)
  int _upFrames = 0; // '다 올라옴' 조건이 연속된 프레임 수
  DateTime? _downAt; // 앉기 시작한 시각

  /// 최근 [c.repSmoothFrames]프레임의 중앙값 (한두 프레임 튀는 값 무시)
  double _smoothedDrop(double raw) {
    _recentDrops.add(raw);
    while (_recentDrops.length > c.repSmoothFrames) {
      _recentDrops.removeAt(0);
    }
    final sorted = List.of(_recentDrops)..sort();
    return sorted[sorted.length ~/ 2];
  }

  /// 프레임마다 호출. 1회가 끝나면 결과를 돌려줌
  RuleRepResult? update(BodyPoints? body, DateTime now) {
    if (body == null) return null; // 인식률 낮은 프레임은 제외
    final m = FrameMetrics(baseline, body, now);
    final h = _smoothedDrop(m.hipDrop);

    if (!_isDown) {
      if (h < _top) _top = h;
      if (h - _top > c.repDownRatio) {
        _isDown = true;
        _peak = h;
        _upFrames = 0;
        _downAt = now;
        _frames
          ..clear()
          ..add(m);
      }
      _updateLive(null);
      return null;
    }

    _frames.add(m);
    if (h > _peak) _peak = h;
    _updateLive(m);

    final returned = h < _top + c.repReturnFraction * (_peak - _top);
    _upFrames = returned ? _upFrames + 1 : 0;
    if (_upFrames < c.repReturnFrames) return null; // 몇 프레임 연속으로 올라와 있어야 인정

    _isDown = false;
    _top = h;
    _upFrames = 0;
    final tooFast = _downAt != null && now.difference(_downAt!) < c.minRepDuration;
    if (tooFast) {
      // 너무 짧은 움직임은 떨림으로 보고 세지 않음
      _frames.clear();
      _liveRun.clear();
      return null;
    }
    final result = _judge();
    _frames.clear();
    _liveRun.clear();
    return result;
  }

  void _updateLive(FrameMetrics? m) {
    if (m == null) {
      _liveRun.clear();
      liveFault = null;
      liveLevel = Level.ok;
      return;
    }
    final now = <SquatFault, Level>{
      SquatFault.kneeCaving: m.kneeCaving,
      // 최저점 항목은 어느 정도 앉았을 때만 실시간으로 봄
      if (m.hipDrop > 0.4) SquatFault.lateralTilt: m.lateralTilt,
      if (m.hipDrop > 0.4) SquatFault.forwardLean: m.forwardLean,
      if (m.hipDrop > 0.4) SquatFault.heelRaise: m.heel,
    };
    SquatFault? best;
    var bestRank = 0;
    for (final f in SquatFault.values) {
      final l = now[f] ?? Level.ok;
      _liveRun[f] = l == Level.ok ? 0 : (_liveRun[f] ?? 0) + 1;
      if ((_liveRun[f] ?? 0) < c.consecutiveFrames) continue;
      // 순위: 판정 대상 오류 > 참고 오류 > 판정 대상 주의 > 참고 주의
      final rank = switch ((f.role, l)) {
        (CheckRole.judged, Level.error) => 4,
        (_, Level.error) => 3,
        (CheckRole.judged, Level.warning) => 2,
        (_, Level.warning) => 1,
        _ => 0,
      };
      if (rank > bestRank) {
        bestRank = rank;
        best = f;
      }
    }
    liveFault = best;
    liveLevel = bestRank >= 3 ? Level.error : (bestRank > 0 ? Level.warning : Level.ok);
  }

  RuleRepResult? _judge() {
    if (_frames.length < 3) return null; // 너무 짧으면 무시 (흔들림)

    // 최저점 구간: 가장 깊은 곳에서 허벅지 길이의 5% 이내 프레임 (최소 3개)
    final deepest = _frames.map((f) => f.hipDrop).reduce(math.max);
    var bottom = _frames.where((f) => f.hipDrop >= deepest - 0.05).toList();
    if (bottom.length < c.consecutiveFrames) {
      bottom = (List.of(_frames)..sort((a, b) => b.hipDrop.compareTo(a.hipDrop)))
          .take(c.consecutiveFrames)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    }

    // 깊이: 연속 3프레임 이상 유지한 깊이 = 3번째로 깊은 값
    final drops = _frames.map((f) => f.hipDrop).toList()..sort((a, b) => b.compareTo(a));
    final sustainedDepth = drops[math.min(c.consecutiveFrames, drops.length) - 1];
    // 흔들림으로 잘못 잡힌 반복은 버림 (실제로 앉은 깊이가 너무 얕음)
    if (sustainedDepth < c.repDownRatio) return null;

    final levels = <SquatFault, Level>{
      SquatFault.kneeCaving: sustainedLevel(_frames.map((f) => f.kneeCaving).toList()),
      SquatFault.shallowDepth: FrameMetrics.below(sustainedDepth, c.depthRatio),
      SquatFault.lateralTilt: sustainedLevel(bottom.map((f) => f.lateralTilt).toList()),
      SquatFault.forwardLean: sustainedLevel(bottom.map((f) => f.forwardLean).toList()),
      SquatFault.heelRaise: sustainedLevel(bottom.map((f) => f.heel).toList()),
    };

    return RuleRepResult(
      levels: levels,
      depthRatio: sustainedDepth,
      startedAt: _frames.first.time,
      endedAt: _frames.last.time,
    );
  }
}
