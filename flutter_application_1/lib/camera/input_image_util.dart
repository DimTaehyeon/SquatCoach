import 'dart:io';
import 'dart:ui' show Size;

import 'package:camera/camera.dart';
import 'package:flutter/foundation.dart' show debugPrint;
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

const _orientations = {
  DeviceOrientation.portraitUp: 0,
  DeviceOrientation.landscapeLeft: 90,
  DeviceOrientation.portraitDown: 180,
  DeviceOrientation.landscapeRight: 270,
};

/// CameraImage → ML Kit InputImage (pose_camera_page.dart와 같은 변환)
InputImage? cameraImageToInputImage(
  CameraImage image,
  CameraDescription camera,
  CameraController controller,
) {
  final sensorOrientation = camera.sensorOrientation;

  InputImageRotation? rotation;
  if (Platform.isIOS) {
    rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
  } else if (Platform.isAndroid) {
    var compensation = _orientations[controller.value.deviceOrientation];
    if (compensation == null) return null;
    if (camera.lensDirection == CameraLensDirection.front) {
      compensation = (sensorOrientation + compensation) % 360;
    } else {
      compensation = (sensorOrientation - compensation + 360) % 360;
    }
    rotation = InputImageRotationValue.fromRawValue(compensation);
  }
  if (rotation == null) return null;

  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null ||
      (Platform.isAndroid && format != InputImageFormat.nv21) ||
      (Platform.isIOS && format != InputImageFormat.bgra8888)) {
    return null;
  }
  if (image.planes.length != 1) return null;
  final plane = image.planes.first;

  return InputImage.fromBytes(
    bytes: plane.bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: format,
      bytesPerRow: plane.bytesPerRow,
    ),
  );
}


/// 앞/뒤 방향마다 "기본 카메라" 1개씩만 남김 (광각·망원 렌즈가 잡히지 않게)
///
/// - iPhone: OS가 렌즈 종류(lensType)를 알려 줌 → 기본 렌즈(wide)를 고름
/// - Android: 렌즈 종류를 알려 주지 않음 → 카메라 ID 숫자가 가장 작은 것을 고름
///   (Android는 기본 카메라에 가장 작은 번호를 줌: 보통 뒤 0번, 앞 1번.
///    광각·망원은 2번 이후 번호로 붙음)
/// 결과 순서: [앞 카메라, 뒤 카메라] (없는 방향은 빠짐)
List<CameraDescription> pickMainCameras(List<CameraDescription> all) {
  CameraDescription? pick(CameraLensDirection dir) {
    final same = all.where((c) => c.lensDirection == dir).toList();
    if (same.isEmpty) return null;
    final wide = same.where((c) => c.lensType == CameraLensType.wide);
    if (wide.isNotEmpty) return wide.first;
    same.sort((a, b) =>
        (int.tryParse(a.name) ?? 1 << 30).compareTo(int.tryParse(b.name) ?? 1 << 30));
    return same.first;
  }

  // 폰마다 카메라 구성이 달라서 확인용으로 터미널에 남김
  for (final c in all) {
    debugPrint('[카메라] ${c.name} · ${c.lensDirection.name} · ${c.lensType.name}');
  }
  return [CameraLensDirection.front, CameraLensDirection.back]
      .map(pick)
      .whereType<CameraDescription>()
      .toList();
}
