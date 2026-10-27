import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' show Size;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// ML Kit 관절 좌표 → 모델 입력 12개 특징값
///
/// 학습 데이터는 MediaPipe 좌표(x, y는 0~1로 정규화, z는 x와 같은 크기)로 만들어졌기 때문에
/// ML Kit의 픽셀 좌표를 같은 크기로 바꾼 뒤 계산합니다.
///
/// ⚠️ 특징값 계산식은 팀원 코드(calculate_angles.py)와 데이터 분포를 보고 맞춘 것입니다.
///    CSV를 만든 원본 스크립트와 다르면 이 파일만 고치면 됩니다.
///   - 무릎 각도: 고관절-무릎-발목 3D 각도 (calculate_angle_3d와 동일)
///   - 고관절 각도: 어깨-고관절-무릎 3D 각도
///   - 발목 각도: 무릎-발목-발끝 3D 각도
///   - spine_angle: 학습 데이터에서 왼쪽 고관절 각도와 값이 같아서 동일하게 계산
///   - torso_lean: 어깨 중심-골반 중심 선의 기울기 (똑바로 서면 90°, 숙일수록 커짐)
///   - knee_lateral: 무릎과 발목의 가로(x) 거리
///   - symmetry_score: |왼무릎-오른무릎| + |왼고관절-오른고관절| (데이터로 확인함)
///   - hip_depth: 골반 중심의 세로(y) 위치 (0 = 화면 위, 1 = 화면 아래)

class _V {
  const _V(this.x, this.y, this.z);
  final double x, y, z;
  _V operator -(_V o) => _V(x - o.x, y - o.y, z - o.z);
  _V mid(_V o) => _V((x + o.x) / 2, (y + o.y) / 2, (z + o.z) / 2);
  double dot(_V o) => x * o.x + y * o.y + z * o.z;
  double get length => math.sqrt(dot(this));
}

/// b를 꼭짓점으로 하는 각도(도)
double _angle(_V a, _V b, _V c) {
  final ba = a - b;
  final bc = c - b;
  final denom = ba.length * bc.length;
  if (denom == 0) return 180;
  final cos = (ba.dot(bc) / denom).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

/// 세 점 [x, y, z]로 b의 각도(도). 팀원 calculate_angle_3d와 같은 식
double angle3d(List<double> a, List<double> b, List<double> c) =>
    _angle(_V(a[0], a[1], a[2]), _V(b[0], b[1], b[2]), _V(c[0], c[1], c[2]));

/// 한 프레임의 분석 결과
class SquatFrame {
  const SquatFrame({
    required this.features,
    required this.kneeAngle2d,
  });

  /// 모델 입력 12개 (kSquatFeatureNames 순서)
  final List<double> features;

  /// 횟수 세기용 무릎 각도 (화면상 2D, 좌우 평균). 서 있으면 ~170°, 앉으면 ~80°
  final double kneeAngle2d;
}

/// 화면에 보이는 방향 기준의 이미지 크기
/// (PosePainter와 같은 규칙: Android는 90/270도 회전 시 가로세로가 바뀜)
Size uprightImageSize(Size imageSize, InputImageRotation rotation) {
  final rotated = rotation == InputImageRotation.rotation90deg ||
      rotation == InputImageRotation.rotation270deg;
  if (Platform.isAndroid && rotated) {
    return Size(imageSize.height, imageSize.width);
  }
  return imageSize;
}

const _required = [
  PoseLandmarkType.leftShoulder,
  PoseLandmarkType.rightShoulder,
  PoseLandmarkType.leftHip,
  PoseLandmarkType.rightHip,
  PoseLandmarkType.leftKnee,
  PoseLandmarkType.rightKnee,
  PoseLandmarkType.leftAnkle,
  PoseLandmarkType.rightAnkle,
];

/// 전신(어깨~발목)이 충분히 보이지 않으면 null
SquatFrame? extractSquatFrame(Pose pose, Size upright,
    {double minLikelihood = 0.5}) {
  for (final t in _required) {
    final lm = pose.landmarks[t];
    if (lm == null || lm.likelihood < minLikelihood) return null;
  }

  final w = upright.width;
  final h = upright.height;

  // MediaPipe 방식으로 정규화한 3D 좌표
  _V n(PoseLandmarkType t) {
    final lm = pose.landmarks[t]!;
    return _V(lm.x / w, lm.y / h, lm.z / w);
  }

  // 화면 픽셀 기준 2D 좌표 (횟수 세기용)
  _V p(PoseLandmarkType t) {
    final lm = pose.landmarks[t]!;
    return _V(lm.x, lm.y, 0);
  }

  // 발끝이 안 보이면 발목 아래쪽으로 대신 잡음 (발목 각도만 영향)
  _V foot(PoseLandmarkType footType, PoseLandmarkType ankleType) {
    final lm = pose.landmarks[footType];
    if (lm != null && lm.likelihood >= 0.3) return n(footType);
    final a = n(ankleType);
    return _V(a.x + 0.03, a.y + 0.01, a.z);
  }

  final ls = n(PoseLandmarkType.leftShoulder);
  final rs = n(PoseLandmarkType.rightShoulder);
  final lh = n(PoseLandmarkType.leftHip);
  final rh = n(PoseLandmarkType.rightHip);
  final lk = n(PoseLandmarkType.leftKnee);
  final rk = n(PoseLandmarkType.rightKnee);
  final la = n(PoseLandmarkType.leftAnkle);
  final ra = n(PoseLandmarkType.rightAnkle);
  final lf = foot(PoseLandmarkType.leftFootIndex, PoseLandmarkType.leftAnkle);
  final rf = foot(PoseLandmarkType.rightFootIndex, PoseLandmarkType.rightAnkle);

  final leftKnee = _angle(lh, lk, la);
  final rightKnee = _angle(rh, rk, ra);
  final leftHip = _angle(ls, lh, lk);
  final rightHip = _angle(rs, rh, rk);
  final leftAnkle = _angle(lk, la, lf);
  final rightAnkle = _angle(rk, ra, rf);

  final shoulderMid = ls.mid(rs);
  final hipMid = lh.mid(rh);
  final tilt = math.atan2(hipMid.y - shoulderMid.y, shoulderMid.x - hipMid.x) *
      180 /
      math.pi;
  final torsoLean = 90 + (tilt - 90).abs(); // 앞/뒤 어느 쪽을 보고 서도 같은 값

  final features = <double>[
    leftKnee,
    rightKnee,
    leftHip,
    rightHip,
    leftAnkle,
    rightAnkle,
    leftHip, // spine_angle
    torsoLean,
    (lk.x - la.x).abs(),
    (rk.x - ra.x).abs(),
    (leftKnee - rightKnee).abs() + (leftHip - rightHip).abs(),
    hipMid.y,
  ];

  final knee2d = (_angle(p(PoseLandmarkType.leftHip), p(PoseLandmarkType.leftKnee),
              p(PoseLandmarkType.leftAnkle)) +
          _angle(p(PoseLandmarkType.rightHip), p(PoseLandmarkType.rightKnee),
              p(PoseLandmarkType.rightAnkle))) /
      2;

  return SquatFrame(features: features, kneeAngle2d: knee2d);
}
