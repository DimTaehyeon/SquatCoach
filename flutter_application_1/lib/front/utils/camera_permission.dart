import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

/// 카메라 권한이 없으면 권한 안내 화면(/permission-again)을 띄워 허용을 받고, 허용됐는지 돌려줍니다.
/// 카메라 준비 화면으로 가기 전에 호출합니다.
Future<bool> ensureCameraPermission(BuildContext context) async {
  if (await Permission.camera.isGranted) return true;
  if (!context.mounted) return false;
  await Navigator.of(context).pushNamed('/permission-again');
  final granted = await Permission.camera.isGranted;
  if (!granted && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('카메라 권한이 있어야 자세를 분석할 수 있어요. 설정에서 카메라를 허용해 주세요')),
    );
  }
  return granted;
}
