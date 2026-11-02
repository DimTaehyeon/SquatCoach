import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../ai/squat_classifier.dart';
import '../ai/squat_features.dart';
import '../camera/input_image_util.dart';
import '../config/squat_criteria.dart' show Level, CheckRole;
import '../db/app_database.dart';
import '../pose_painter.dart';
import '../ui/app_colors.dart';
import '../workout/workout_controller.dart';
import 'session_detail_page.dart';

/// 운동 화면: 카메라 + 실시간 판정 + 세트 관리
///
/// 영점 조절(2초) → 세트 진행 → 세트 완료 → 다음 세트 / 운동 종료 → 결과 화면
class WorkoutPage extends StatefulWidget {
  const WorkoutPage({super.key});

  @override
  State<WorkoutPage> createState() => _WorkoutPageState();
}

class _WorkoutPageState extends State<WorkoutPage> with WidgetsBindingObserver {
  final _detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );

  WorkoutController? _workout;
  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _busy = false;
  bool _saving = false;
  bool _showAi = false;
  String? _error;

  List<Pose> _poses = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  // 피드백 지연 측정 (프레임이 들어와서 판정이 끝나기까지)
  double _latencyMs = 0; // 프레임 1장 분석 시간, 이동 평균
  double _fps = 0; // 1초에 분석이 끝나는 프레임 수
  int _fpsCount = 0;
  DateTime _fpsStart = DateTime.now();

  // 사물 오인식 방지: 사람처럼 보이는 프레임이 이만큼 연속돼야 판정 (30fps 기준 약 0.17초)
  static const _personFramesNeeded = 5;
  int _personFrames = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _init();
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
    if (_cameras.isEmpty) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      _startCamera();
    }
  }

  Future<void> _init() async {
    final user = await AppDatabase.instance.getOrCreateDefaultUser();
    _workout = WorkoutController(userId: user.id!, weightKg: user.weightKg);
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = '사용 가능한 카메라가 없습니다.');
        return;
      }
      final front =
          _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = front == -1 ? 0 : front;
      await _startCamera();
    } on CameraException catch (e) {
      setState(() => _error = '카메라 오류: ${e.description}');
    }
  }

  Future<void> _startCamera() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup:
          Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _controller = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_onFrame);
      setState(() {});
    } on CameraException catch (e) {
      setState(() => _error = '카메라 오류: ${e.description}');
    }
  }

  Future<void> _stopCamera() async {
    final controller = _controller;
    _controller = null;
    if (controller == null) return;
    if (controller.value.isStreamingImages) await controller.stopImageStream();
    await controller.dispose();
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    setState(() {
      _poses = [];
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    _workout?.restartCalibration();
    await _startCamera();
  }

  // ---------------- 프레임 ----------------

  Future<void> _onFrame(CameraImage image) async {
    final workout = _workout;
    final controller = _controller;
    if (_busy || workout == null || controller == null) return;
    _busy = true;
    final t0 = DateTime.now();
    try {
      final input = cameraImageToInputImage(image, _cameras[_cameraIndex], controller);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted) return;
      final meta = input.metadata!;
      final now = DateTime.now();

      final upright = uprightImageSize(meta.size, meta.rotation);
      final isPerson =
          poses.isNotEmpty && looksLikePerson(poses.first, upright);
      _personFrames = isPerson ? _personFrames + 1 : 0;
      final personReady = _personFrames >= _personFramesNeeded;

      final wasCalibrating = workout.phase == WorkoutPhase.calibrating;
      final repDone =
          workout.onFrame(personReady ? poses.first : null, upright, now);

      if (repDone) HapticFeedback.mediumImpact();
      if (wasCalibrating && workout.phase == WorkoutPhase.active) {
        HapticFeedback.lightImpact();
        final stance = workout.baseline?.stanceLevel ?? Level.ok;
        if (stance != Level.ok && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('참고: 발을 어깨너비 정도로 벌리면 더 안정적이에요'),
            duration: Duration(seconds: 3),
          ));
        }
      }

      final ms = DateTime.now().difference(t0).inMicroseconds / 1000;
      _fpsCount++;
      final elapsed = DateTime.now().difference(_fpsStart).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = _fpsCount * 1000 / elapsed;
        _fpsCount = 0;
        _fpsStart = DateTime.now();
        debugPrint('[지연] 분석 ${_latencyMs.toStringAsFixed(0)}ms · '
            '${_fps.toStringAsFixed(1)}fps');
      }
      setState(() {
        _poses = personReady ? poses : []; // 사물에는 뼈대를 그리지 않음
        _imageSize = meta.size;
        _rotation = meta.rotation;
        _latencyMs = _latencyMs == 0 ? ms : _latencyMs * 0.9 + ms * 0.1;
      });
    } catch (e) {
      debugPrint('workout frame error: $e');
    } finally {
      _busy = false;
    }
  }

  // ---------------- 버튼 ----------------

  void _completeSet() {
    setState(() => _workout!.completeSet());
  }

  void _nextSet() {
    setState(() => _workout!.startNextSet());
  }

  Future<void> _finish() async {
    final workout = _workout!;
    if (_saving) return;
    if (!workout.hasAnyReps) {
      Navigator.pop(context);
      return;
    }
    setState(() => _saving = true);
    int? id;
    try {
      id = await workout.finishAndSave(); // 저장 후 DB에서 다시 읽어 값 확인
    } catch (e) {
      debugPrint('저장 실패: $e');
      if (!mounted) return;
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        backgroundColor: AppColors.serious,
        content: Text('저장에 실패했어요. 기록은 남아 있으니 다시 눌러 주세요'),
      ));
      return;
    }
    await _stopCamera();
    if (!mounted) return;
    if (id == null) {
      Navigator.pop(context);
      return;
    }
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: id!, isResult: true)),
    );
  }

  /// 뒤로가기: 기록이 있으면 저장할지 물어봄
  Future<void> _onBack() async {
    final workout = _workout;
    if (workout == null || !workout.hasAnyReps) {
      Navigator.pop(context);
      return;
    }
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('운동을 끝낼까요?'),
        content: Text('지금까지 ${workout.totalReps}회를 했어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('저장 안 함')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'continue'), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('저장하고 종료')),
        ],
      ),
    );
    if (!mounted) return;
    if (choice == 'save') {
      await _finish();
    } else if (choice == 'discard') {
      Navigator.pop(context);
    }
  }

  // ---------------- 화면 ----------------

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(appBar: AppBar(), body: Center(child: Text(_error!)));
    }
    final controller = _controller;
    final workout = _workout;
    if (controller == null || !controller.value.isInitialized || workout == null) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _onBack();
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          children: [
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
                          lensDirection: _cameras[_cameraIndex].lensDirection,
                        ),
                      ),
              ),
            ),
            SafeArea(
              child: Column(
                children: [
                  _topBar(workout),
                  _statusBanner(workout),
                  if (_showAi) _aiPanel(workout),
                  const Spacer(),
                  if (workout.phase == WorkoutPhase.resting)
                    _restPanel(workout)
                  else
                    _bottomPanel(workout),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _circleButton(IconData icon, String tooltip, VoidCallback onTap,
      {bool active = false}) {
    return Padding(
      padding: const EdgeInsets.only(left: 8),
      child: Material(
        color: active ? AppColors.series : Colors.black54,
        shape: const CircleBorder(),
        child: IconButton(
          tooltip: tooltip,
          onPressed: onTap,
          icon: Icon(icon, color: Colors.white, size: 22),
        ),
      ),
    );
  }

  Widget _topBar(WorkoutController w) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: '뒤로',
              onPressed: _onBack,
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              w.phase == WorkoutPhase.resting ? '휴식 중' : '세트 ${w.setNumber}',
              style: const TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w800,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
          _circleButton(Icons.analytics_outlined, 'AI 참고 판정 보기',
              () => setState(() => _showAi = !_showAi),
              active: _showAi),
          if (_cameras.length > 1) _circleButton(Icons.cameraswitch, '카메라 전환', _switchCamera),
        ],
      ),
    );
  }

  Widget _banner({
    required IconData icon,
    required Color color,
    required String title,
    required String sub,
    Widget? extra,
  }) {
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xD9242422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(160), width: 1.5),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 30),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: const TextStyle(
                          fontSize: 19,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        )),
                    const SizedBox(height: 2),
                    Text(sub,
                        style: const TextStyle(fontSize: 13.5, color: AppColors.textSecondary)),
                  ],
                ),
              ),
            ],
          ),
          if (extra != null) ...[const SizedBox(height: 10), extra],
        ],
      ),
    );
  }

  Widget _statusBanner(WorkoutController w) {
    final now = DateTime.now();
    switch (w.phase) {
      case WorkoutPhase.calibrating:
        final issue = w.calibrationIssue;
        return _banner(
          icon: Icons.accessibility_new,
          color: issue == null ? AppColors.series : AppColors.warning,
          title: '영점 조절 중',
          sub: issue ?? '정면을 보고 똑바로 서서 2초만 기다려 주세요',
          extra: ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: w.calibrationProgress(now),
              minHeight: 6,
              color: AppColors.series,
              backgroundColor: AppColors.grid,
            ),
          ),
        );

      case WorkoutPhase.resting:
        final set = w.sets.last;
        return _banner(
          icon: Icons.self_improvement,
          color: AppColors.textSecondary,
          title: '세트 ${set.setIndex} 완료',
          sub: '${set.totalReps}회 중 ${set.goodReps}회 정자세 · 숨을 고르고 다음 세트를 시작하세요',
        );

      case WorkoutPhase.active:
        if (!w.bodyVisible) {
          return _banner(
            icon: Icons.crop_free,
            color: AppColors.warning,
            title: '전신이 보이지 않아요',
            sub: '머리부터 발끝까지 화면에 들어오게 서 주세요',
          );
        }
        // 방금 끝난 반복 결과 (1.5초 동안)
        final last = w.lastRep;
        final lastAt = w.lastRepAt;
        if (last != null &&
            lastAt != null &&
            now.difference(lastAt) < const Duration(milliseconds: 1500) &&
            !w.isDown) {
          final good = last.isGood;
          final mainFault = good ? null : last.faults.first;
          return _banner(
            icon: good ? Icons.check_circle : Icons.error,
            color: good ? AppColors.good : AppColors.serious,
            title: good ? '${w.currentReps.length}회 · 정자세!' : '${w.currentReps.length}회 · ${mainFault!.label}',
            sub: good
                ? (last.warnings.isEmpty ? '좋아요, 그대로 계속하세요' : '참고: ${last.warnings.first.feedback}')
                : mainFault!.feedback,
          );
        }
        final live = w.tracker?.liveFault;
        if (w.isDown && live != null) {
          final isError = w.tracker!.liveLevel == Level.error;
          return _banner(
            icon: isError ? Icons.error : Icons.remove_circle,
            color: isError ? AppColors.serious : AppColors.warning,
            title: live.label + (live.role == CheckRole.reference ? ' (참고)' : ''),
            sub: live.feedback,
          );
        }
        return _banner(
          icon: Icons.accessibility_new,
          color: AppColors.good,
          title: w.isDown ? '좋아요, 그대로!' : '준비 완료',
          sub: w.isDown ? '천천히 일어서세요' : '천천히 앉았다 일어서면 1회로 세요',
        );
    }
  }

  Widget _aiPanel(WorkoutController w) {
    final probs = w.aiProbs;
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 8, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
      decoration: BoxDecoration(
        color: const Color(0xD9242422),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'AI 모델 참고 판정 · 분석 ${_latencyMs.toStringAsFixed(0)}ms · ${_fps.toStringAsFixed(0)}fps',
            style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 6),
          for (final c in SquatClass.values)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 2),
              child: Row(
                children: [
                  SizedBox(
                    width: 92,
                    child: Text(c.label,
                        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: probs == null ? 0 : probs[c.index],
                        minHeight: 7,
                        color: AppColors.series,
                        backgroundColor: AppColors.grid,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      probs == null ? '-' : '${(probs[c.index] * 100).toStringAsFixed(0)}%',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _panel({required List<Widget> children}) {
    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6242422),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }

  Widget _bottomPanel(WorkoutController w) {
    final reps = w.currentReps.length;
    return _panel(children: [
      Row(
        children: [
          _bigStat('횟수', '$reps', '회'),
          _bigStat('정자세', '${w.currentGood}', '회'),
          _bigStat('정확도', reps == 0 ? '-' : w.currentAccuracy.toStringAsFixed(0), reps == 0 ? '' : '%'),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _finish,
              child: const Text('운동 종료'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: reps == 0 ? null : _completeSet,
              child: const Text('세트 완료'),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _restPanel(WorkoutController w) {
    final total = w.totalReps;
    return _panel(children: [
      Row(
        children: [
          _bigStat('완료 세트', '${w.sets.length}', '세트'),
          _bigStat('누적 횟수', '$total', '회'),
        ],
      ),
      const SizedBox(height: 12),
      Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _saving ? null : _finish,
              child: Text(_saving ? '저장 중…' : '운동 종료'),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: FilledButton(
              onPressed: _nextSet,
              child: const Text('다음 세트'),
            ),
          ),
        ],
      ),
    ]);
  }

  Widget _bigStat(String label, String value, String unit) {
    return Expanded(
      child: Column(
        children: [
          Text.rich(TextSpan(children: [
            TextSpan(
              text: value,
              style: const TextStyle(
                fontSize: 30,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            TextSpan(
              text: unit,
              style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ])),
          Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
