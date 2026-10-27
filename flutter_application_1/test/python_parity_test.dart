// 10.23~25 검수: Dart 계산 결과가 팀원(A)의 Python 결과와 같은지 확인
//
// 정답값(test/fixtures/python_reference.json)은 Aiproject의
//   - calculate_angles.py 의 calculate_angle_3d  (각도)
//   - squat_model.tflite + scaler.pkl            (모델 확률)
// 로 직접 계산해서 만든 것입니다.
//
// 실행: flutter test test/python_parity_test.dart

import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter_application_1/ai/squat_classifier.dart';
import 'package:flutter_application_1/ai/squat_features.dart';
import 'package:flutter_application_1/ai/squat_model_data.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final data = jsonDecode(
    File('test/fixtures/python_reference.json').readAsStringSync(),
  ) as Map<String, dynamic>;

  List<double> xyz(Map<String, dynamic> m) => [
        (m['x'] as num).toDouble(),
        (m['y'] as num).toDouble(),
        (m['z'] as num).toDouble(),
      ];

  test('모델 입력 순서가 학습 때(scaler.pkl)와 같다', () {
    expect(kSquatFeatureNames, equals(List<String>.from(data['feature_order'] as List)));
  });

  test('무릎 각도: Dart angle3d == Python calculate_angle_3d', () {
    final cases = (data['angles'] as List).cast<Map<String, dynamic>>();
    var maxDiff = 0.0;
    for (final c in cases) {
      final dart = angle3d(
        xyz(c['hip'] as Map<String, dynamic>),
        xyz(c['knee'] as Map<String, dynamic>),
        xyz(c['ankle'] as Map<String, dynamic>),
      );
      final python = (c['expected_left_knee_angle'] as num).toDouble();
      maxDiff = math.max(maxDiff, (dart - python).abs());
      expect(dart, closeTo(python, 0.001), reason: '프레임 ${c['frame']}');
    }
    // ignore: avoid_print
    print('각도 ${cases.length}개 비교 · 최대 차이 ${maxDiff.toStringAsExponential(2)}도');
  });

  test('모델 판정: Dart SquatClassifier == TFLite', () {
    const classifier = SquatClassifier();
    final cases = (data['model'] as List).cast<Map<String, dynamic>>();
    var maxDiff = 0.0;
    for (final c in cases) {
      final features =
          (c['features'] as List).map((v) => (v as num).toDouble()).toList();
      final expected =
          (c['expected_probs'] as List).map((v) => (v as num).toDouble()).toList();
      final probs = classifier.predict(features);

      for (var i = 0; i < probs.length; i++) {
        maxDiff = math.max(maxDiff, (probs[i] - expected[i]).abs());
        expect(probs[i], closeTo(expected[i], 1e-4),
            reason: '${c['video']} 프레임 ${c['frame']}, 클래스 $i');
      }
      // 가장 높은 확률의 자세(최종 판정)도 같은지
      expect(topClass(probs).index, topClass(expected).index,
          reason: '${c['video']} 프레임 ${c['frame']}');
    }
    // ignore: avoid_print
    print('모델 ${cases.length}개 비교 · 확률 최대 차이 ${maxDiff.toStringAsExponential(2)}');
  });
}
