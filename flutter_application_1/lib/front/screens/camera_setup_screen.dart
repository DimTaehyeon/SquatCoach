import 'dart:io';
import 'dart:math' as math;

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../ai/squat_features.dart' show extractSquatFrame, looksLikePerson, uprightImageSize;
import '../../camera/input_image_util.dart';
import '../../config/squat_criteria.dart' show minFrontalShoulderToThigh;
import '../../pose_painter.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import 'countdown_screen.dart';

/// 카메라 준비 (Figma: 카메라) — 실제 카메라(백엔드의 포즈 인식)를 열어
/// 전신 인식, 정면 각도, 밝기를 확인하며 자세를 맞추는 화면입니다.
/// (카메라 권한은 이 화면에 오기 전에 받습니다.)
/// 측정 시작 → 3-2-1 카운트다운 → 운동 분석(영점 조절)
class CameraSetupScreen extends StatefulWidget {
  const CameraSetupScreen({super.key});

  @override
  State<CameraSetupScreen> createState() => _CameraSetupScreenState();
}

class _CameraSetupScreenState extends State<CameraSetupScreen> with WidgetsBindingObserver {
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base),
  );

  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  int _cameraIndex = 0;
  bool _busy = false;
  bool _starting = false;
  bool _initializing = false;
  Future<void>? _stopping;
  String? _error;

  List<Pose> _poses = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  int _personFrames = 0;
  double _luminance = 0;
  bool _bodyOk = false;
  bool _angleOk = false;
  static const _minLuminance = 70.0;
  static const _autoStartSeconds = 2.5; // 세 조건이 이 시간 동안 계속 만족되면 자동으로 카운트다운 시작
  static const _skipAfterSeconds = 20; // 이 시간이 지나도 못 넘어가면 "건너뛰기" 표시
  DateTime? _bodySince; // 세 조건이 연속으로 만족된 시작 시각
  double _hold = 0; // 세 조건을 연속으로 만족한 시간(초)
  final DateTime _openedAt = DateTime.now();
  bool _showSkip = false;

  bool get _brightnessOk => _luminance >= _minLuminance;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _detector.close();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameras.isEmpty || _starting || _initializing) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  Future<void> _initCamera() async {
    if (_initializing) return;
    _initializing = true;
    if (mounted) setState(() => _error = null);
    try {
      _cameras = pickMainCameras(await availableCameras());
      if (_cameras.isEmpty) {
        if (mounted) setState(() => _error = '사용 가능한 카메라가 없어요.');
        return;
      }
      final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = front == -1 ? 0 : front;
      await _openCamera();
    } catch (e) {
      _showCameraError(e);
    } finally {
      _initializing = false;
    }
  }

  void _showCameraError(Object e) {
    if (!mounted) return;
    final denied = e is CameraException && e.code.toLowerCase().contains('denied');
    setState(() => _error = denied
        ? '카메라 권한이 필요해요.\n설정 > 앱 > 권한에서 카메라를 허용한 뒤 "다시 시도"를 눌러 주세요.'
        : '카메라를 사용할 수 없어요.\n"다시 시도"를 눌러 주세요.');
  }

  Future<void> _openCamera() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _camera = controller;
    await controller.initialize();
    if (!mounted || _camera != controller) {
      await controller.dispose();
      return;
    }
    await controller.startImageStream(_onFrame);
    if (mounted) setState(() {});
  }

  Future<void> _startCamera() async {
    if (_initializing) return;
    _initializing = true;
    try {
      await _openCamera();
    } catch (e) {
      _showCameraError(e);
    } finally {
      _initializing = false;
    }
  }

  Future<void> _stopCamera() async {
    final controller = _camera;
    _camera = null;
    if (controller == null) return;
    for (var i = 0; i < 20 && _busy; i++) {
      await Future.delayed(const Duration(milliseconds: 50));
    }
    try {
      if (controller.value.isStreamingImages) {
        await controller.stopImageStream().timeout(const Duration(seconds: 2));
      }
    } catch (e) {
      debugPrint('stopImageStream 실패: $e');
    }
    try {
      await controller.dispose().timeout(const Duration(seconds: 2));
    } catch (e) {
      debugPrint('camera dispose 실패: $e');
    }
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    setState(() {
      _poses = [];
      _bodyOk = false;
      _angleOk = false;
      _personFrames = 0;
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    await _startCamera();
  }

  // ---------------- 프레임 검사 ----------------

  double _measureLuminance(CameraImage image) {
    final bytes = image.planes[0].bytes;
    if (bytes.isEmpty) return 0;
    var sum = 0.0;
    var n = 0;
    if (Platform.isAndroid) {
      final yLen = math.min(bytes.length, image.width * image.height);
      for (var i = 0; i < yLen; i += 97) {
        sum += bytes[i];
        n++;
      }
    } else {
      for (var i = 0; i + 2 < bytes.length; i += 4 * 97) {
        sum += 0.114 * bytes[i] + 0.587 * bytes[i + 1] + 0.299 * bytes[i + 2];
        n++;
      }
    }
    return n == 0 ? 0 : sum / n;
  }

  /// 정면인지: 어깨 너비가 허벅지 길이에 비해 충분히 넓어야 함
  bool _isFrontal(Pose pose) {
    double d(PoseLandmark a, PoseLandmark b) => math.sqrt(math.pow(a.x - b.x, 2) + math.pow(a.y - b.y, 2));
    final lm = pose.landmarks;
    final ls = lm[PoseLandmarkType.leftShoulder], rs = lm[PoseLandmarkType.rightShoulder];
    final lh = lm[PoseLandmarkType.leftHip], rh = lm[PoseLandmarkType.rightHip];
    final lk = lm[PoseLandmarkType.leftKnee], rk = lm[PoseLandmarkType.rightKnee];
    if (ls == null || rs == null || lh == null || rh == null || lk == null || rk == null) return false;
    final thigh = (d(lh, lk) + d(rh, rk)) / 2;
    if (thigh <= 0) return false;
    return d(ls, rs) >= thigh * minFrontalShoulderToThigh;
  }

  Future<void> _onFrame(CameraImage image) async {
    final camera = _camera;
    if (_busy || _starting || camera == null) return;
    _busy = true;
    try {
      final lum = _measureLuminance(image);
      _luminance = _luminance == 0 ? lum : _luminance * 0.8 + lum * 0.2;

      final input = cameraImageToInputImage(image, _cameras[_cameraIndex], camera);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted || _starting) return;
      final meta = input.metadata!;
      final upright = uprightImageSize(meta.size, meta.rotation);

      final person = poses.isNotEmpty && looksLikePerson(poses.first, upright);
      _personFrames = person ? _personFrames + 1 : 0;
      final body = _personFrames >= 5 && extractSquatFrame(poses.first, upright) != null;

      final now = DateTime.now();
      final angle = body && _isFrontal(poses.first);
      final allOk = body && angle && _brightnessOk; // 전신 + 정면 + 밝기
      if (allOk) {
        _bodySince ??= now;
      } else {
        _bodySince = null;
      }
      final hold = _bodySince == null ? 0.0 : now.difference(_bodySince!).inMilliseconds / 1000;

      setState(() {
        _hold = hold;
        _bodyOk = body;
        _angleOk = angle;
        _showSkip = now.difference(_openedAt).inSeconds >= _skipAfterSeconds;
        _poses = body ? poses : [];
        _imageSize = meta.size;
        _rotation = meta.rotation;
      });
      if (hold >= _autoStartSeconds) _start(); // 전신이 2~3초 인식되면 자동 시작
    } catch (e) {
      debugPrint('camera setup frame error: $e');
    } finally {
      _busy = false;
    }
  }

  // ---------------- 시작 ----------------

  /// "측정 시작": 같은 화면 위에 3-2-1 카운트다운을 겹쳐 보여줍니다. (조건을 못 채웠어도 누르면 넘어감)
  /// 카메라 끄기는 카운트다운 뒤에서 처리합니다.
  void _start() {
    if (_starting) return;
    _bodySince = null;
    setState(() => _starting = true); // 프레임 분석 멈춤 + 카운트다운 표시
    _stopping = _stopCamera();
  }

  Future<void> _onCountdownDone(bool completed) async {
    await _stopping; // 각 단계에 시간 제한이 있어 오래 걸리지 않음
    if (!mounted) return;
    if (completed) {
      Navigator.of(context).pushReplacementNamed('/analysis');
    } else {
      // 카운트다운에서 닫기(X): 카메라 준비 화면으로 돌아와 카메라를 다시 켬
      setState(() {
        _starting = false;
        _poses = [];
        _bodyOk = false;
        _angleOk = false;
        _personFrames = 0;
        _hold = 0;
        _showSkip = false;
      });
      await _startCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: _page(context)),
        if (_starting) Positioned.fill(child: CountdownScreen(onDone: _onCountdownDone)),
      ],
    );
  }

  Widget _page(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              const SizedBox(height: 8),
              ScreenHeader(
                title: '카메라 준비',
                onBack: () => Navigator.of(context).maybePop(),
                trailing: _cameras.length > 1
                    ? RoundIconButton(icon: Icons.cameraswitch_outlined, onTap: _switchCamera)
                    : null,
              ),
              const SizedBox(height: 10),
              const Text(
                '정면(앞모습)이 화면에 들어오도록 폰을 세워주세요. 양쪽 무릎과 발끝이 모두 보여야 정확하게 분석돼요. 영상은 저장하거나 전송하지 않아요.',
                style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.5),
              ),
              const SizedBox(height: 12),
              Expanded(
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(gradient: AppColors.cameraGradient, borderRadius: BorderRadius.circular(24)),
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Positioned.fill(child: _preview()),
                      Positioned(
                        top: 12,
                        left: 12,
                        right: 12,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 8),
                          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(10)),
                          child: Text(
                              (_bodyOk && _angleOk && _brightnessOk)
                                  ? '좋아요! 그대로 서 계세요 (${(_autoStartSeconds - _hold).clamp(0, _autoStartSeconds).ceil()}초 후 자동 시작)'
                                  : '전신이 프레임 안에 들어오도록 조정해주세요',
                              textAlign: TextAlign.center,
                              style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w600)),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SoftCard(
                radius: 18,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                child: Column(
                  children: [
                    _check(_bodyOk ? '전신 인식 완료' : '전신 인식 중... 머리부터 발끝까지 보이게 서 주세요', _bodyOk),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    _check(_angleOk ? '정면 각도 적절함' : '카메라를 정면으로 보고 서 주세요', _angleOk),
                    const Divider(height: 1, color: AppColors.cardBorder),
                    _check(
                      _luminance == 0 ? '밝기 확인 중...' : (_brightnessOk ? '밝기 확인 완료' : '조금 더 밝은 곳에서 찍어 주세요'),
                      _luminance != 0 && _brightnessOk,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 14),
              if (_showSkip)
                TextButton(
                  onPressed: _start,
                  child: const Text('건너뛰고 바로 시작', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                )
              else
                const Text('세 가지 조건이 확인되면 자동으로 시작돼요',
                    style: TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
              const SizedBox(height: 6),
              const Text('빌드 v12', style: TextStyle(fontSize: 9, color: AppColors.textMuted)), // 설치된 버전 확인용
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Widget _preview() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!,
                  textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: () async {
                  await _stopCamera();
                  _initCamera();
                },
                style: OutlinedButton.styleFrom(foregroundColor: Colors.white, side: const BorderSide(color: Colors.white70)),
                child: const Text('다시 시도'),
              ),
            ],
          ),
        ),
      );
    }
    final camera = _camera;
    if (camera == null || !camera.value.isInitialized) {
      return const Center(child: CircularProgressIndicator(color: Colors.white70));
    }
    return Center(
      child: CameraPreview(
        camera,
        child: _imageSize == null
            ? null
            : CustomPaint(
                painter: PosePainter(
                  poses: _poses,
                  imageSize: _imageSize!,
                  rotation: _rotation,
                  lensDirection: _cameras[_cameraIndex].lensDirection,
                ),
              ),
      ),
    );
  }

  Widget _check(String text, bool ok) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            width: 20,
            height: 20,
            decoration: BoxDecoration(
              color: ok ? AppColors.primary : Colors.white,
              shape: BoxShape.circle,
              border: Border.all(color: ok ? AppColors.primary : AppColors.cardBorder, width: 1.4),
            ),
            child: ok ? const Icon(Icons.check_rounded, size: 13, color: Colors.white) : null,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: ok ? FontWeight.w700 : FontWeight.w500,
                  color: ok ? AppColors.textDark : AppColors.textMuted,
                )),
          ),
        ],
      ),
    );
  }
}
