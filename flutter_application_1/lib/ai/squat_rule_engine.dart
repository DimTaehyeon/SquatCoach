import 'dart:math' as math;

import 'package:flutter/foundation.dart' show debugPrint;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../config/squat_criteria.dart' as c;
import '../config/squat_criteria.dart'
    show Level, SquatFault, CheckRole, Threshold, JudgeCriteria;

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

  /// 어깨선 기울기(°, 방향 포함). 폰이 비뚤게 서 있어도 서 있을 때 값을 빼면 상쇄됨
  double get shoulderTiltSigned =>
      math.atan2(ls.y - rs.y, shoulderWidth.clamp(1e-6, double.infinity)) * 180 / math.pi;

  /// 골반 좌우 높이 차(방향 포함, 픽셀)
  double get pelvisTiltSigned => lh.y - rh.y;

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
    this.shoulderTilt = 0,
    this.pelvisTilt = 0,
  });

  final double thigh, shin, torso, ankleWidth, shoulderWidth;
  final double hipMidX, hipMidY;
  final double shoulderTilt; // 서 있을 때 어깨선 기울기(°, 폰 기울기 포함)
  final double pelvisTilt; // 서 있을 때 골반 좌우 높이 차(픽셀)
  final double? heelY;

  /// 가만히 서 있는 여러 프레임의 평균으로 영점을 만듦
  factory StandingBaseline.fromFrames(List<BodyPoints> frames) {
    double avg(double Function(BodyPoints) f) =>
        frames.map(f).reduce((a, b) => a + b) / frames.length;
    final heels = frames.map((f) => f.heelY).whereType<double>().toList();
    return StandingBaseline(
      thigh: avg((f) => f.thigh),
      shin: avg((f) => f.shin),
      torso: avg((f) => f.torsoHeight),
      ankleWidth: avg((f) => f.ankleWidth),
      shoulderWidth: avg((f) => f.shoulderWidth),
      hipMidX: avg((f) => f.hipMid.x),
      hipMidY: avg((f) => f.hipMid.y),
      shoulderTilt: avg((f) => f.shoulderTiltSigned),
      pelvisTilt: avg((f) => f.pelvisTiltSigned),
      heelY: heels.length >= frames.length / 2
          ? heels.reduce((a, b) => a + b) / heels.length
          : null,
    );
  }

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

    final baseline = StandingBaseline.fromFrames(_frames);
    reset();
    return baseline;
  }
}

// ───────────────────────── 프레임별 측정값 ─────────────────────────

class FrameMetrics {
  FrameMetrics(StandingBaseline b, BodyPoints p, this.time)
      : hipDrop = (p.hipMid.y - b.hipMidY) / b.thigh,
        kneeRatio = p.ankleWidth > 0 ? p.kneeWidth / p.ankleWidth : 1.0,
        // 기울기 2개는 서 있을 때 값을 빼서 '더 기운 만큼'만 봄 (폰이 비뚤어도 영향 없음)
        shoulderTiltDeg = (p.shoulderTiltSigned - b.shoulderTilt).abs(),
        pelvisTilt = (p.pelvisTiltSigned - b.pelvisTilt).abs() / b.thigh,
        pelvisShift =
            b.ankleWidth > 0 ? (p.hipMid.x - b.hipMidX).abs() / b.ankleWidth : 0.0,
        torsoRatio = b.torso > 0 ? p.torsoHeight / b.torso : 1.0,
        footX = p.la.mid(p.ra).x,
        footY = p.la.mid(p.ra).y,
        shoulderWidthPx = p.shoulderWidth,
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
  final double footX, footY; // 양 발목 가운데 (픽셀) — 걷기 판별용
  final double shoulderWidthPx; // 어깨 폭 (픽셀) — 카메라와 거리 변화 판별용
  final double? heelRise;

  /// 작을수록 나쁜 값
  static Level below(double v, Threshold t) =>
      v < t.error ? Level.error : (v < t.warning ? Level.warning : Level.ok);

  /// 클수록 나쁜 값
  static Level above(double v, Threshold t) =>
      v > t.error ? Level.error : (v > t.warning ? Level.warning : Level.ok);

  Level kneeCaving(JudgeCriteria k) => below(kneeRatio, k.kneeCaving);

  /// 몸이 좌우로 기울어짐: 3개 지표 중 가장 나쁜 단계
  Level lateralTilt(JudgeCriteria k) => _worst([
        above(shoulderTiltDeg, k.shoulderTilt),
        above(pelvisTilt, k.pelvisTilt),
        above(pelvisShift, k.pelvisShift),
      ]);

  Level get forwardLean => below(torsoRatio, c.forwardLeanRatio);

  Level get heel => heelRise == null ? Level.ok : above(heelRise!, c.heelRaiseRatio);
}

Level _worst(Iterable<Level> levels) =>
    levels.fold(Level.ok, (a, b) => a.index >= b.index ? a : b);

/// 기준을 넘은 상태가 모드별 조건(초보자 0.3초 / 일반 연속 3프레임) 이상 이어지면 그 단계로 인정
/// 구간 전체가 그보다 짧으면, 구간 전체가 기준을 넘을 때만 인정
Level sustainedLevel(
    List<FrameMetrics> frames, Level Function(FrameMetrics) levelOf, JudgeCriteria k) {
  if (frames.isEmpty) return Level.ok;
  bool hasRun(bool Function(Level) hit) {
    var n = 0;
    DateTime? start;
    for (final f in frames) {
      if (!hit(levelOf(f))) {
        n = 0;
        start = null;
        continue;
      }
      n++;
      start ??= f.time;
      if (k.isSustained(n, f.time.difference(start)) || n == frames.length) return true;
    }
    return false;
  }

  if (hasRun((l) => l == Level.error)) return Level.error;
  if (hasRun((l) => l != Level.ok)) return Level.warning;
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
  RuleRepTracker(this.baseline, this.criteria);

  /// 영점. 세트 중에 사용자가 자리를 옮기면 서 있을 때 자동으로 다시 잡음
  StandingBaseline baseline;

  /// 세트 중 영점을 다시 잡은 횟수 (확인용)
  int rebaselineCount = 0;
  final JudgeCriteria criteria; // 초보자 / 일반 모드 기준값
  final List<FrameMetrics> _frames = [];
  bool _isDown = false;

  /// 실시간 피드백용: 항목별 연속 프레임 수와 시작 시각
  final Map<SquatFault, int> _liveRun = {};
  final Map<SquatFault, DateTime> _liveSince = {};

  bool get isDown => _isDown;

  /// 지금 화면에 띄울 피드백 (연속 3프레임 이상 걸린 것 중 가장 중요한 것)
  SquatFault? liveFault;
  Level liveLevel = Level.ok;

  double _top = double.infinity; // 최근 [c.standingWindow] 동안 서 있던 높이 (hipDrop 최솟값)
  double _repTop = 0; // 이번 반복을 시작하기 직전의 서 있던 높이
  final List<(DateTime, double)> _standLevels = []; // 서 있는 동안의 (시각, 높이)
  final List<(DateTime, BodyPoints)> _standBodies = []; // 영점 재조정용 서 있는 자세
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
      // 서 있는 높이 = 최근 1.5초 중 가장 높은 자세 (예전 값에 영원히 묶이지 않게)
      _standLevels.add((now, h));
      _standLevels.removeWhere((e) => now.difference(e.$1) > c.standingWindow);
      _top = _standLevels.map((e) => e.$2).reduce(math.min);

      if (h - _top > c.repDownRatio) {
        _isDown = true;
        _repTop = _top;
        _standBodies.clear();
        _peak = h;
        _upFrames = 0;
        _downAt = now;
        _frames
          ..clear()
          ..add(m);
      }
      if (!_isDown) _maybeRebaseline(body, now); // 서 있을 때만 영점 재조정 확인
      _updateLive(null);
      return null;
    }

    _frames.add(m);
    if (h > _peak) _peak = h;
    _updateLive(m);

    final returned = h < _repTop + c.repReturnFraction * (_peak - _repTop);
    _upFrames = returned ? _upFrames + 1 : 0;
    if (_upFrames < c.repReturnFrames) return null; // 몇 프레임 연속으로 올라와 있어야 인정

    _isDown = false;
    _standLevels.clear();
    _upFrames = 0;
    final tooFast = _downAt != null && now.difference(_downAt!) < c.minRepDuration;
    if (tooFast) {
      // 너무 짧은 움직임은 떨림으로 보고 세지 않음
      _frames.clear();
      _liveRun.clear();
      _liveSince.clear();
      return null;
    }
    if (_isWalking()) {
      // 자리를 옮기며 낮아진 움직임은 스쿼트가 아님
      debugPrint('[횟수] 걷는 움직임이라 세지 않음');
      _frames.clear();
      _liveRun.clear();
      _liveSince.clear();
      return null;
    }
    final result = _judge();
    _frames.clear();
    _liveRun.clear();
    _liveSince.clear();
    return result;
  }

  /// 이번 반복 동안 발이 움직였거나 카메라와 거리가 크게 바뀌었으면 걷는 중
  bool _isWalking() {
    if (_frames.length < 2) return false;
    double range(Iterable<double> v) => v.reduce(math.max) - v.reduce(math.min);
    final footMove = math.max(range(_frames.map((f) => f.footX)), range(_frames.map((f) => f.footY)));
    final widths = _frames.map((f) => f.shoulderWidthPx).where((w) => w > 0);
    final scale = widths.isEmpty ? 1.0 : widths.reduce(math.max) / widths.reduce(math.min);
    return footMove / baseline.thigh > c.walkFootMove || scale > c.walkScaleChange;
  }

  /// 가만히 서 있는데 영점 때와 위치·거리가 달라졌으면 지금 자리로 영점을 다시 잡음. 다시 잡았으면 true
  bool _maybeRebaseline(BodyPoints body, DateTime now) {
    // 정면을 보고 있을 때만 (옆으로 돌아서 걸어가는 중이면 X)
    if (body.shoulderWidth < body.thigh * c.minFrontalShoulderToThigh) {
      _standBodies.clear();
      return false;
    }
    _standBodies.add((now, body));
    _standBodies.removeWhere((e) => now.difference(e.$1) > c.rebaselineStillTime);
    if (_standBodies.length < 8 ||
        now.difference(_standBodies.first.$1) <
            c.rebaselineStillTime - const Duration(milliseconds: 100)) {
      return false;
    }

    // 1초 동안 엉덩이가 거의 움직이지 않았는지
    final ys = _standBodies.map((e) => e.$2.hipMid.y);
    final thigh = _standBodies.first.$2.thigh;
    if (thigh <= 0 || (ys.reduce(math.max) - ys.reduce(math.min)) / thigh > c.rebaselineStillRatio) {
      return false;
    }

    final cand = StandingBaseline.fromFrames(_standBodies.map((e) => e.$2).toList());
    final b = baseline;
    final moved = (cand.hipMidY - b.hipMidY).abs() / b.thigh > c.rebaselineHeightDiff ||
        (cand.thigh / b.thigh - 1).abs() > c.rebaselineScaleDiff ||
        (b.ankleWidth > 0 && (cand.hipMidX - b.hipMidX).abs() / b.ankleWidth > c.rebaselineSideDiff);
    if (!moved) return false;

    baseline = cand;
    rebaselineCount++;
    // 단위가 바뀌었으니 높이 기록은 새로 시작
    _recentDrops.clear();
    _standLevels.clear();
    _standBodies.clear();
    _top = double.infinity;
    debugPrint('[영점] 자리 이동 감지 → 영점 다시 잡음 ($rebaselineCount번째)');
    return true;
  }

  void _updateLive(FrameMetrics? m) {
    if (m == null) {
      _liveRun.clear();
      _liveSince.clear();
      liveFault = null;
      liveLevel = Level.ok;
      return;
    }
    final now = <SquatFault, Level>{
      SquatFault.kneeCaving: m.kneeCaving(criteria),
      // 최저점 항목은 어느 정도 앉았을 때만 실시간으로 봄
      if (m.hipDrop > 0.4) SquatFault.lateralTilt: m.lateralTilt(criteria),
      if (m.hipDrop > 0.4) SquatFault.forwardLean: m.forwardLean,
      if (m.hipDrop > 0.4) SquatFault.heelRaise: m.heel,
    };
    SquatFault? best;
    var bestRank = 0;
    for (final f in SquatFault.values) {
      final l = now[f] ?? Level.ok;
      if (l == Level.ok) {
        _liveRun[f] = 0;
        _liveSince.remove(f);
        continue;
      }
      _liveRun[f] = (_liveRun[f] ?? 0) + 1;
      final since = _liveSince.putIfAbsent(f, () => m.time);
      if (!criteria.isSustained(_liveRun[f]!, m.time.difference(since))) continue;
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
    if (bottom.length < c.depthSustainFrames) {
      bottom = (List.of(_frames)..sort((a, b) => b.hipDrop.compareTo(a.hipDrop)))
          .take(c.depthSustainFrames)
          .toList()
        ..sort((a, b) => a.time.compareTo(b.time));
    }

    // 깊이: 연속 3프레임 이상 유지한 깊이 = 3번째로 깊은 값
    final drops = _frames.map((f) => f.hipDrop).toList()..sort((a, b) => b.compareTo(a));
    // 영점이 아니라 '이번 반복 직전에 서 있던 높이'에서 얼마나 내려갔는지로 잼
    // (자리를 옮겨 영점이 조금 어긋나도 깊이가 틀어지지 않게)
    final sustainedDepth =
        drops[math.min(c.depthSustainFrames, drops.length) - 1] - _repTop;
    // 흔들림으로 잘못 잡힌 반복은 버림 (실제로 앉은 깊이가 너무 얕음)
    if (sustainedDepth < c.repDownRatio) return null;

    final levels = <SquatFault, Level>{
      SquatFault.kneeCaving: sustainedLevel(_frames, (f) => f.kneeCaving(criteria), criteria),
      SquatFault.shallowDepth: FrameMetrics.below(sustainedDepth, criteria.depth),
      SquatFault.lateralTilt: sustainedLevel(bottom, (f) => f.lateralTilt(criteria), criteria),
      SquatFault.forwardLean: sustainedLevel(bottom, (f) => f.forwardLean, criteria),
      SquatFault.heelRaise: sustainedLevel(bottom, (f) => f.heel, criteria),
    };

    return RuleRepResult(
      levels: levels,
      depthRatio: sustainedDepth,
      startedAt: _frames.first.time,
      endedAt: _frames.last.time,
    );
  }
}
