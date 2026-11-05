import 'package:flutter/material.dart';

/// 관절 인덱스 (MediaPipe Pose 33개 랜드마크 중 자세 판정에 필요한 13개만 간략화).
/// 실제 MediaPipe 연동 시에는 landmarks를 이 순서/형태(0~1로 정규화된 Offset 리스트)로
/// 변환해서 FigurePainter에 넘겨주면 그대로 동작합니다.
class PoseJoint {
  static const nose = 0;
  static const leftShoulder = 1;
  static const rightShoulder = 2;
  static const leftElbow = 3;
  static const rightElbow = 4;
  static const leftWrist = 5;
  static const rightWrist = 6;
  static const leftHip = 7;
  static const rightHip = 8;
  static const leftKnee = 9;
  static const rightKnee = 10;
  static const leftAnkle = 11;
  static const rightAnkle = 12;
}

const List<List<int>> poseConnections = [
  [PoseJoint.leftShoulder, PoseJoint.rightShoulder],
  [PoseJoint.leftShoulder, PoseJoint.leftElbow],
  [PoseJoint.leftElbow, PoseJoint.leftWrist],
  [PoseJoint.rightShoulder, PoseJoint.rightElbow],
  [PoseJoint.rightElbow, PoseJoint.rightWrist],
  [PoseJoint.leftShoulder, PoseJoint.leftHip],
  [PoseJoint.rightShoulder, PoseJoint.rightHip],
  [PoseJoint.leftHip, PoseJoint.rightHip],
  [PoseJoint.leftHip, PoseJoint.leftKnee],
  [PoseJoint.leftKnee, PoseJoint.leftAnkle],
  [PoseJoint.rightHip, PoseJoint.rightKnee],
  [PoseJoint.rightKnee, PoseJoint.rightAnkle],
];

/// t = 0(서있음) ~ 1(앉음) 사이 값으로 간단한 스쿼트 동작의 관절 좌표(0~1)를 만드는 Mock 함수.
List<Offset> generateMockSquatPose(double t) {
  final hipDrop = 0.12 * t;
  final kneeBend = 0.05 * t;
  final hipY = 0.46 + hipDrop;
  final kneeY = 0.68 + hipDrop + kneeBend;
  final kneeSpread = 0.06 * t;

  final joints = List<Offset>.filled(13, Offset.zero);
  joints[PoseJoint.nose] = Offset(0.5, 0.18 + hipDrop * 0.3);
  joints[PoseJoint.leftShoulder] = Offset(0.40, 0.28 + hipDrop * 0.3);
  joints[PoseJoint.rightShoulder] = Offset(0.60, 0.28 + hipDrop * 0.3);
  joints[PoseJoint.leftElbow] = Offset(0.33, 0.40 + hipDrop * 0.3);
  joints[PoseJoint.rightElbow] = Offset(0.67, 0.40 + hipDrop * 0.3);
  joints[PoseJoint.leftWrist] = Offset(0.30, 0.50 + hipDrop * 0.3);
  joints[PoseJoint.rightWrist] = Offset(0.70, 0.50 + hipDrop * 0.3);
  joints[PoseJoint.leftHip] = Offset(0.43, hipY);
  joints[PoseJoint.rightHip] = Offset(0.57, hipY);
  joints[PoseJoint.leftKnee] = Offset(0.43 - kneeSpread, kneeY);
  joints[PoseJoint.rightKnee] = Offset(0.57 + kneeSpread, kneeY);
  joints[PoseJoint.leftAnkle] = Offset(0.43, 0.92);
  joints[PoseJoint.rightAnkle] = Offset(0.57, 0.92);
  return joints;
}

/// Figma 스타일 스켈레톤: 흰 선 + 머리 원 + 상체 관절(주황) + 무릎(초록, 자세가 나쁘면 빨강).
class FigurePainter extends CustomPainter {
  FigurePainter({required this.joints, this.goodForm = true});

  final List<Offset> joints;
  final bool goodForm;

  static const _upperJoint = Color(0xFFF2A93B);
  static const _lowerGood = Color(0xFF63D98B);
  static const _lowerBad = Color(0xFFE85C4A);

  @override
  void paint(Canvas canvas, Size size) {
    if (joints.length < 13) return;
    Offset p(int i) => Offset(joints[i].dx * size.width, joints[i].dy * size.height);

    final line = Paint()
      ..color = Colors.white
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round;

    for (final c in poseConnections) {
      canvas.drawLine(p(c[0]), p(c[1]), line);
    }

    // 목 선 + 머리 원
    final shoulderMid = Offset(
      (p(PoseJoint.leftShoulder).dx + p(PoseJoint.rightShoulder).dx) / 2,
      (p(PoseJoint.leftShoulder).dy + p(PoseJoint.rightShoulder).dy) / 2,
    );
    final head = p(PoseJoint.nose);
    final headRadius = size.width * 0.05;
    canvas.drawLine(Offset(head.dx, head.dy + headRadius), shoulderMid, line);
    canvas.drawCircle(
      head,
      headRadius,
      Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3,
    );

    final upper = Paint()..color = _upperJoint;
    final lower = Paint()..color = goodForm ? _lowerGood : _lowerBad;
    for (final i in [
      PoseJoint.leftShoulder,
      PoseJoint.rightShoulder,
      PoseJoint.leftHip,
      PoseJoint.rightHip,
    ]) {
      canvas.drawCircle(p(i), 5, upper);
    }
    for (final i in [PoseJoint.leftKnee, PoseJoint.rightKnee]) {
      canvas.drawCircle(p(i), 5, lower);
    }
  }

  @override
  bool shouldRepaint(covariant FigurePainter old) => old.joints != joints || old.goodForm != goodForm;
}

/// 자체적으로 스쿼트 모션을 반복 재생하는 스켈레톤 오버레이.
class AnimatedPoseOverlay extends StatefulWidget {
  const AnimatedPoseOverlay({super.key, this.goodForm = true, this.active = true});

  final bool goodForm;
  final bool active;

  @override
  State<AnimatedPoseOverlay> createState() => _AnimatedPoseOverlayState();
}

class _AnimatedPoseOverlayState extends State<AnimatedPoseOverlay> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void didUpdateWidget(covariant AnimatedPoseOverlay oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.active && !_controller.isAnimating) {
      _controller.repeat(reverse: true);
    } else if (!widget.active) {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        painter: FigurePainter(joints: generateMockSquatPose(_controller.value), goodForm: widget.goodForm),
        child: const SizedBox.expand(),
      ),
    );
  }
}

/// 흐릿한 회색 정면 사람(인식 실패/카운트다운/일시정지 배경용).
class DimFigure extends StatelessWidget {
  const DimFigure({super.key, this.color = const Color(0xFF5C6862)});

  final Color color;

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _DimFigurePainter(color), child: const SizedBox.expand());
}

class _DimFigurePainter extends CustomPainter {
  _DimFigurePainter(this.color);
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    Offset o(double x, double y) => Offset(x * size.width, y * size.height);
    final stroke = Paint()
      ..color = color
      ..strokeWidth = size.width * 0.035
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    stroke.style = PaintingStyle.stroke;
    Path line(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.dx, pt.dy);
      }
      return p;
    }
    // 정면: 머리, 어깨, 몸통, 양팔, 양다리
    canvas.drawCircle(o(0.50, 0.15), size.width * 0.07, Paint()..color = color);
    canvas.drawPath(line([o(0.36, 0.28), o(0.64, 0.28)]), stroke);
    canvas.drawPath(line([o(0.50, 0.26), o(0.50, 0.55)]), stroke);
    canvas.drawPath(line([o(0.36, 0.28), o(0.30, 0.44), o(0.34, 0.56)]), stroke);
    canvas.drawPath(line([o(0.64, 0.28), o(0.70, 0.44), o(0.66, 0.56)]), stroke);
    canvas.drawPath(line([o(0.50, 0.55), o(0.40, 0.70), o(0.40, 0.88)]), stroke);
    canvas.drawPath(line([o(0.50, 0.55), o(0.60, 0.70), o(0.60, 0.88)]), stroke);
  }

  @override
  bool shouldRepaint(covariant _DimFigurePainter old) => old.color != color;
}
