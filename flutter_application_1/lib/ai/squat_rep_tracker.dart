import 'squat_classifier.dart';

/// 반복 1회 동안 팀 AI 모델이 낸 판정을 모아 가장 많이 나온 것을 고름 (참고용)
///
/// 최종 정상/오류 판정은 판정 기준 문서의 규칙(squat_rule_engine.dart)으로 하고,
/// 모델 결과는 화면의 "AI 참고"와 반복 기록(ai_label)에만 남깁니다.
class AiVoteCollector {
  final List<int> _votes = List.filled(SquatClass.values.length, 0);
  final List<double> _probSum = List.filled(SquatClass.values.length, 0);
  int _frames = 0;

  /// 가장 최근 프레임의 확률 (화면 표시용)
  List<double>? lastProbs;

  void add(List<double> probs) {
    lastProbs = probs;
    _votes[topClass(probs).index]++;
    for (var i = 0; i < probs.length; i++) {
      _probSum[i] += probs[i];
    }
    _frames++;
  }

  /// 모은 프레임이 없으면 null
  SquatClass? get majority {
    if (_frames == 0) return null;
    var best = 0;
    for (var i = 1; i < _votes.length; i++) {
      if (_votes[i] > _votes[best]) best = i;
    }
    return SquatClass.values[best];
  }

  /// 평균 확률 (프레임이 없으면 null)
  List<double>? get averageProbs =>
      _frames == 0 ? null : _probSum.map((v) => v / _frames).toList();

  void reset() {
    _votes.fillRange(0, _votes.length, 0);
    _probSum.fillRange(0, _probSum.length, 0);
    _frames = 0;
  }
}
