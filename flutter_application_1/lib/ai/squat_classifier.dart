import 'dart:math' as math;

import 'squat_model_data.dart';

/// 모델이 구분하는 6가지 자세
///
/// ⚠️ 라벨 번호 → 의미는 학습 데이터(squat_features_augmented.csv)에서
/// 라벨마다 어떤 값이 바뀌었는지를 보고 추정한 것입니다. 팀원 확인 필요!
///   0: 원본 값 그대로                         → 정상
///   1: 무릎·고관절 각도가 커짐 (덜 굽힘)       → 깊이 부족
///   2: 척추 각도↓, 상체 기울기↑               → 상체 과다 숙임
///   3: 무릎 각도↓, 무릎-발목 가로 간격↑       → 무릎 과다 전진
///   4: 발목 각도가 커짐                       → 뒤꿈치 들림
///   5: 왼쪽/오른쪽 각도가 반대로 바뀜          → 좌우 비대칭
enum SquatClass { normal, shallow, leanForward, kneeForward, heelRaise, asymmetric }

extension SquatClassInfo on SquatClass {
  String get label => switch (this) {
        SquatClass.normal => '정자세',
        SquatClass.shallow => '깊이 부족',
        SquatClass.leanForward => '상체 과다 숙임',
        SquatClass.kneeForward => '무릎 과다 전진',
        SquatClass.heelRaise => '뒤꿈치 들림',
        SquatClass.asymmetric => '좌우 비대칭',
      };

  String get feedback => switch (this) {
        SquatClass.normal => '좋아요! 지금 자세를 유지하세요',
        SquatClass.shallow => '조금 더 깊이 앉아 주세요',
        SquatClass.leanForward => '가슴을 펴고 상체를 세워 주세요',
        SquatClass.kneeForward => '엉덩이를 뒤로 빼고 무릎이 앞으로 나가지 않게 하세요',
        SquatClass.heelRaise => '뒤꿈치를 바닥에 붙여 주세요',
        SquatClass.asymmetric => '양쪽 다리에 체중을 고르게 실어 주세요',
      };
}

/// 팀원이 학습한 squat_model.tflite 와 똑같은 계산을 Dart로 수행
/// (입력 12개 → 표준화 → Dense 128 → 64 → 32 → 6 → softmax)
class SquatClassifier {
  const SquatClassifier();

  /// 12개 특징값 → 6개 자세의 확률 (합 = 1)
  List<double> predict(List<double> features) {
    assert(features.length == kScalerMean.length);

    // 1) 학습 때와 같은 기준으로 표준화: (x - 평균) / 표준편차
    var h = List<double>.generate(
      features.length,
      (i) => (features[i] - kScalerMean[i]) / kScalerScale[i],
    );

    // 2) 완전연결층 4개 (마지막 층 빼고 ReLU)
    final lastLayer = kLayerWeights.length - 1;
    for (var l = 0; l <= lastLayer; l++) {
      final w = kLayerWeights[l];
      final b = kLayerBiases[l];
      final out = List<double>.filled(w.length, 0);
      for (var o = 0; o < w.length; o++) {
        final row = w[o];
        var sum = b[o];
        for (var i = 0; i < row.length; i++) {
          sum += row[i] * h[i];
        }
        out[o] = (l < lastLayer && sum < 0) ? 0 : sum;
      }
      h = out;
    }

    // 3) softmax → 확률
    final maxLogit = h.reduce(math.max);
    final exps = h.map((v) => math.exp(v - maxLogit)).toList();
    final total = exps.fold<double>(0, (a, b) => a + b);
    return exps.map((v) => v / total).toList();
  }
}

/// 확률 리스트에서 가장 높은 자세
SquatClass topClass(List<double> probs) {
  var best = 0;
  for (var i = 1; i < probs.length; i++) {
    if (probs[i] > probs[best]) best = i;
  }
  return SquatClass.values[best];
}
