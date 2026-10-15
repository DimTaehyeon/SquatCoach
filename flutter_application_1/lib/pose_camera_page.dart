import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../pose_painter.dart';

/// 카메라 실시간 스트림 → ML Kit Pose Detection → 화면 위에 뼈대 그리기
class PoseCameraPage extends StatefulWidget {
  const PoseCameraPage({super.key});

  @override
  State<PoseCameraPage> createState() => _PoseCameraPageState();
}

class _PoseCameraPageState extends State<PoseCameraPage>
    with WidgetsBindingObserver {
  // stream 모드: 연속 프레임용 (이전 프레임 결과를 활용해 더 빠르고 안정적)
  // base 모델이 빠르고, accurate 모델은 더 정확하지만 느림
  final PoseDetector _poseDetector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = -1;

  bool _isBusy = false; // 이전 프레임 처리 중이면 새 프레임은 건너뜀
  List<Pose> _poses = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  String? _error;

  // FPS 측정 (자세 인식이 1초에 몇 번 끝나는지)
  int _frameCount = 0;
  DateTime _fpsStart = DateTime.now();
  double _fps = 0;

  static const Map<DeviceOrientation, int> _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCameras();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _poseDetector.close();
    super.dispose();
  }

  // 앱이 백그라운드로 가면 카메라를 끄고, 돌아오면 다시 켬
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameras.isEmpty) return;
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _startCamera();
    }
  }

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = '사용 가능한 카메라가 없습니다.');
        return;
      }
      // 운동 자세는 보통 셀카 방향으로 보니까 전면 카메라를 기본으로
      _cameraIndex = _cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      if (_cameraIndex == -1) _cameraIndex = 0;
      await _startCamera();
    } on CameraException catch (e) {
      setState(() => _error = '카메라 오류: ${e.description}');
    }
  }

  Future<void> _startCamera() async {
    final camera = _cameras[_cameraIndex];
    final controller = CameraController(
      camera,
      ResolutionPreset.medium, // 높을수록 느려짐. 자세 인식엔 medium이면 충분
      enableAudio: false,
      // ML Kit가 받는 포맷: Android = NV21, iOS = BGRA8888
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _controller = controller;

    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_processCameraImage);
      setState(() => _error = null);
    } on CameraException catch (e) {
      setState(() => _error = '카메라 오류: ${e.description}');
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) {
      await controller.stopImageStream();
    }
    await controller.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    setState(() {
      _poses = [];
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    await _startCamera();
  }

  /// 카메라 프레임마다 호출됨
  Future<void> _processCameraImage(CameraImage image) async {
    if (_isBusy) return;
    _isBusy = true;
    try {
      final inputImage = _toInputImage(image);
      if (inputImage == null) return;

      final poses = await _poseDetector.processImage(inputImage);
      if (!mounted) return;

      _updateFps();
      setState(() {
        _poses = poses;
        _imageSize = inputImage.metadata!.size;
        _rotation = inputImage.metadata!.rotation;
      });
    } catch (e) {
      debugPrint('Pose detection error: $e');
    } finally {
      _isBusy = false;
    }
  }

  /// CameraImage → ML Kit InputImage 변환 (회전값 계산 포함)
  InputImage? _toInputImage(CameraImage image) {
    final controller = _controller;
    if (controller == null) return null;

    final camera = _cameras[_cameraIndex];
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
      debugPrint('지원하지 않는 이미지 포맷: ${image.format.raw}');
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

  void _updateFps() {
    _frameCount++;
    final elapsed = DateTime.now().difference(_fpsStart).inMilliseconds;
    if (elapsed >= 1000) {
      _fps = _frameCount * 1000 / elapsed;
      _frameCount = 0;
      _fpsStart = DateTime.now();
    }
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;

    if (_error != null) {
      return Scaffold(
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text(_error!, textAlign: TextAlign.center),
          ),
        ),
      );
    }

    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final lens = _cameras[_cameraIndex].lensDirection;
    final landmarkCount = _poses.isEmpty
        ? 0
        : _poses.first.landmarks.values.where((l) => l.likelihood > 0.5).length;

    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          // CameraPreview의 child는 미리보기와 같은 크기로 겹쳐지므로
          // 뼈대 좌표가 화면과 정확히 맞음
          Center(
            child: CameraPreview(
              controller,
              child: _imageSize == null
                  ? null
                  : CustomPaint(
                      painter: PosePainter(
                        poses: _poses,
                        imageSize: _imageSize!,
                        rotation: _rotation,
                        lensDirection: lens,
                      ),
                    ),
            ),
          ),
          // 상단 상태 표시
          SafeArea(
            child: Container(
              margin: const EdgeInsets.all(12),
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}   '
                '사람: ${_poses.isEmpty ? "없음" : "감지됨"}   '
                '관절: $landmarkCount/33',
                style: const TextStyle(fontSize: 14, color: Colors.white),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: _cameras.length > 1
          ? FloatingActionButton(
              onPressed: _switchCamera,
              child: const Icon(Icons.cameraswitch),
            )
          : null,
    );
  }
}