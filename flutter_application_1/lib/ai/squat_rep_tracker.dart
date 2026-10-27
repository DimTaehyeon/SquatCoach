import 'squat_classifier.dart';

/// 반복 1회의 판정 결과
class RepResult {
  const RepResult({
    required this.index,
    required this.verdict,
    required this.score,
    required this.minKneeAngle,
    required this.endedAt,
  });

  final int index; // 1부터
  final SquatClass verdict; // 그 반복 동안 가장 많이 나온 자세
  final double score; // 0~100: 앉아 있는 동안 '정자세' 확률의 평균
  final double minKneeAngle; // 가장 깊이 앉았을 때 무릎 각도(2D)
  final DateTime endedAt;

  bool get isGood => verdict == SquatClass.normal;
}

/// 무릎 각도로 앉았다 일어서는 것을 세고, 앉아 있는 동안의 AI 판정을 모아
/// 반복 1회마다 결과를 냄
///
/// 학습 데이터에는 '서 있는 자세'가 거의 없어서, 서 있을 때는 판정하지 않고
/// 무릎이 [judgeBelow]보다 굽혀졌을 때만 AI 결과를 사용합니다.
class SquatRepTracker {
  SquatRepTracker({
    this.downBelow = 130,
    this.upAbove = 160,
    this.judgeBelow = 140,
  });

  final double downBelow; // 이 각도보다 작아지면 '앉음'
  final double upAbove; // 앉은 뒤 이 각도보다 커지면 '일어섬' → 1회
  final double judgeBelow; // 이 각도보다 작을 때의 프레임만 판정에 사용

  final List<RepResult> reps = [];
  DateTime? firstRepStartedAt;

  bool _isDown = false;
  DateTime? _repStartedAt;
  final List<double> _probSum = List.filled(SquatClass.values.length, 0);
  final List<int> _votes = List.filled(SquatClass.values.length, 0);
  int _judgedFrames = 0;
  double _minKnee = 180;

  bool get isDown => _isDown;
  int get goodCount => reps.where((r) => r.isGood).length;

  /// 프레임마다 호출. 반복 1회가 끝나면 그 결과를 돌려줌
  RepResult? update(double kneeAngle2d, List<double> probs, DateTime now) {
    if (kneeAngle2d < judgeBelow) {
      _repStartedAt ??= now;
      for (var i = 0; i < probs.length; i++) {
        _probSum[i] += probs[i];
      }
      _votes[topClass(probs).index]++;
      _judgedFrames++;
      if (kneeAngle2d < _minKnee) _minKnee = kneeAngle2d;
    }

    if (!_isDown && kneeAngle2d < downBelow) {
      _isDown = true;
    } else if (_isDown && kneeAngle2d > upAbove) {
      _isDown = false;
      RepResult? result;
      if (_judgedFrames >= 3) {
        result = _finishRep(now);
        reps.add(result);
        firstRepStartedAt ??= _repStartedAt;
      }
      _clearRep();
      return result;
    }
    return null;
  }

  RepResult _finishRep(DateTime now) {
    var best = 0;
    for (var i = 1; i < _votes.length; i++) {
      if (_votes[i] > _votes[best]) best = i;
    }
    return RepResult(
      index: reps.length + 1,
      verdict: SquatClass.values[best],
      score: _probSum[SquatClass.normal.index] / _judgedFrames * 100,
      minKneeAngle: _minKnee,
      endedAt: now,
    );
  }

  void _clearRep() {
    _probSum.fillRange(0, _probSum.length, 0);
    _votes.fillRange(0, _votes.length, 0);
    _judgedFrames = 0;
    _minKnee = 180;
    _repStartedAt = null;
  }

  /// 세트 초기화
  void reset() {
    reps.clear();
    firstRepStartedAt = null;
    _isDown = false;
    _clearRep();
  }

  /// "깊이 부족 2회 · 상체 과다 숙임 1회" 같은 요약
  String faultSummary() {
    final counts = <SquatClass, int>{};
    for (final r in reps.where((r) => !r.isGood)) {
      counts[r.verdict] = (counts[r.verdict] ?? 0) + 1;
    }
    if (counts.isEmpty) return '모든 반복 정자세';
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return sorted.map((e) => '${e.key.label} ${e.value}회').join(' · ');
  }
}
