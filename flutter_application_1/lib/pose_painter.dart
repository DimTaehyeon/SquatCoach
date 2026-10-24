import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// ML Kit가 준 관절 좌표(카메라 이미지 기준)를 화면 좌표로 바꿔서 뼈대를 그림
class PosePainter extends CustomPainter {
  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.lensDirection,
  });

  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection lensDirection;

  /// 이 값보다 신뢰도가 낮은 관절은 그리지 않음
  static const double minLikelihood = 0.5;

  // 몸 왼쪽 = 하늘색, 오른쪽 = 주황색, 가운데 = 흰색
  static final Paint _leftPaint = Paint()
    ..color = Colors.cyanAccent
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  static final Paint _rightPaint = Paint()
    ..color = Colors.orangeAccent
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  static final Paint _centerPaint = Paint()
    ..color = Colors.white
    ..strokeWidth = 4
    ..strokeCap = StrokeCap.round;
  static final Paint _jointPaint = Paint()..color = Colors.greenAccent;

  static const _l = PoseLandmarkType.values;

  // 연결할 관절 쌍
  static const List<(PoseLandmarkType, PoseLandmarkType)> _leftBones = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow),
    (PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist),
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip),
    (PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee),
    (PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle),
    (PoseLandmarkType.leftAnkle, PoseLandmarkType.leftHeel),
    (PoseLandmarkType.leftHeel, PoseLandmarkType.leftFootIndex),
    (PoseLandmarkType.leftAnkle, PoseLandmarkType.leftFootIndex),
  ];
  static const List<(PoseLandmarkType, PoseLandmarkType)> _rightBones = [
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow),
    (PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist),
    (PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip),
    (PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee),
    (PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle),
    (PoseLandmarkType.rightAnkle, PoseLandmarkType.rightHeel),
    (PoseLandmarkType.rightHeel, PoseLandmarkType.rightFootIndex),
    (PoseLandmarkType.rightAnkle, PoseLandmarkType.rightFootIndex),
  ];
  static const List<(PoseLandmarkType, PoseLandmarkType)> _centerBones = [
    (PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder),
    (PoseLandmarkType.leftHip, PoseLandmarkType.rightHip),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    for (final pose in poses) {
      Offset? point(PoseLandmarkType type) {
        final lm = pose.landmarks[type];
        if (lm == null || lm.likelihood < minLikelihood) return null;
        return Offset(
          _translateX(lm.x, size),
          _translateY(lm.y, size),
        );
      }

      void drawBones(
          List<(PoseLandmarkType, PoseLandmarkType)> bones, Paint paint) {
        for (final (a, b) in bones) {
          final p1 = point(a);
          final p2 = point(b);
          if (p1 != null && p2 != null) canvas.drawLine(p1, p2, paint);
        }
      }

      drawBones(_leftBones, _leftPaint);
      drawBones(_rightBones, _rightPaint);
      drawBones(_centerBones, _centerPaint);

      for (final type in _l) {
        final p = point(type);
        if (p != null) canvas.drawCircle(p, 5, _jointPaint);
      }
    }
  }

  double _translateX(double x, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x *
            canvasSize.width /
            (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation270deg:
        return canvasSize.width -
            x *
                canvasSize.width /
                (Platform.isIOS ? imageSize.width : imageSize.height);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        if (lensDirection == CameraLensDirection.back) {
          return x * canvasSize.width / imageSize.width;
        }
        return canvasSize.width - x * canvasSize.width / imageSize.width;
    }
  }

  double _translateY(double y, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        return y *
            canvasSize.height /
            (Platform.isIOS ? imageSize.height : imageSize.width);
      case InputImageRotation.rotation0deg:
      case InputImageRotation.rotation180deg:
        return y * canvasSize.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter old) =>
      old.poses != poses ||
      old.imageSize != imageSize ||
      old.rotation != rotation ||
      old.lensDirection != lensDirection;
}