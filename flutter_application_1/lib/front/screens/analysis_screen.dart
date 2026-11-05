import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';
import 'package:provider/provider.dart';

import '../../ai/squat_features.dart' show looksLikePerson, uprightImageSize;
import '../../camera/input_image_util.dart';
import '../../config/squat_criteria.dart' show CheckRole, Level, SquatFault;
import '../../pose_painter.dart';
import '../../workout/workout_controller.dart';
import '../providers/profile_provider.dart';
import '../providers/session_provider.dart';
import '../services/alert_coach.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/bottom_nav_bar.dart';
import '../widgets/common.dart';
import '../widgets/primary_button.dart';
import 'countdown_screen.dart';
import 'paused_screen.dart';
import 'rest_between_sets_screen.dart';

/// 운동 분석 (Figma: 운동하기) — 실제 카메라 + 자세 인식(ML Kit) + 백엔드 판정.
///
/// 흐름: 영점 조절(2초 똑바로 서기) → 세트 진행(앉았다 일어서면 1회) → 목표 횟수/세트 종료 → 휴식 → …
///       → 마지막 세트 또는 운동 끝내기 → DB 저장 → 결과 화면
/// 판정·횟수 세기는 SessionProvider.controller(WorkoutController)가 하고, 이 화면은 카메라 프레임을 넘기고 결과를 보여줍니다.
class AnalysisScreen extends StatefulWidget {
  const AnalysisScreen({super.key});

  @override
  State<AnalysisScreen> createState() => _AnalysisScreenState();
}

class _AnalysisScreenState extends State<AnalysisScreen> with WidgetsBindingObserver {
  final _detector = PoseDetector(
    options: PoseDetectorOptions(mode: PoseDetectionMode.stream, model: PoseDetectionModel.base),
  );

  List<CameraDescription> _cameras = [];
  CameraController? _camera;
  int _cameraIndex = 0;
  bool _busy = false;
  Widget? _overlay; // 휴식/카운트다운을 화면 위에 겹쳐 보여줄 때 사용 (새 화면으로 이동하지 않음)
  bool _leaving = false; // 휴식/결과 화면으로 넘어가는 중
  final AlertCoach _alert = AlertCoach();
  final Set<SquatFault> _alertedThisRep = {}; // 이번 앉기에서 이미 소리로 알린 오류 (같은 오류는 한 번만)
  String? _error;

  List<Pose> _poses = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;

  // 사물 오인식 방지: 사람처럼 보이는 프레임이 연속돼야 판정 (30fps 기준 약 0.17초)
  static const _personFramesNeeded = 5;
  int _personFrames = 0;
  // 앉을 때 인식이 풀리지 않게: 한 번 잡은 사람은 잠깐(약 0.3초) 놓쳐도 계속 추적
  static const _maxMissedFrames = 10;
  int _missedFrames = 0;
  DateTime? _noBodySince; // 영점 조절 중 몸이 안 보이기 시작한 시각 (오래 지속되면 인식 실패 화면)

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final profile = context.read<ProfileProvider>().user;
    _alert.voiceEnabled = profile.voiceEnabled;
    _alert.soundEnabled = profile.soundEnabled;
    _alert.init();
    _bootstrap();
    // 첫 카운트다운(3-2-1)은 카메라 준비 화면에서 이미 끝났습니다. 바로 영점 조절이 시작됩니다.
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _stopCamera();
    _detector.close();
    _alert.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameras.isEmpty) return;
    if (state == AppLifecycleState.inactive || state == AppLifecycleState.paused) {
      _stopCamera();
    } else if (state == AppLifecycleState.resumed && _camera == null) {
      _startCamera();
    }
  }

  // ---------------- 카메라 ----------------

  /// 운동 데이터(DB·판정 모델)를 준비한 뒤 카메라를 켭니다. (카운트다운 중에는 아직 준비 전일 수 있음)
  Future<void> _bootstrap() async {
    final session = context.read<SessionProvider>();
    if (session.controller == null) {
      try {
        final weight = context.read<ProfileProvider>().user.weightKg;
        await session.startWorkout(weightKg: weight).timeout(const Duration(seconds: 10));
      } catch (e) {
        if (mounted) setState(() => _error = '운동을 준비하지 못했어요.\n($e)\n뒤로 나가서 다시 시도해 주세요.');
        return;
      }
    }
    if (!mounted) return;
    await _initCamera();
  }

  Future<void> _initCamera() async {
    try {
      _cameras = pickMainCameras(await availableCameras()); // 기본 카메라만 (광각 X)
      if (_cameras.isEmpty) {
        setState(() => _error = '사용 가능한 카메라가 없어요.');
        return;
      }
      final front = _cameras.indexWhere((c) => c.lensDirection == CameraLensDirection.front);
      _cameraIndex = front == -1 ? 0 : front;
      await _startCamera();
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = '카메라를 사용할 수 없어요 (${e.description ?? e.code}).\n설정에서 카메라 권한을 허용해 주세요.');
    }
  }

  Future<void> _startCamera() async {
    final controller = CameraController(
      _cameras[_cameraIndex],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: Platform.isAndroid ? ImageFormatGroup.nv21 : ImageFormatGroup.bgra8888,
    );
    _camera = controller;
    try {
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_onFrame);
      setState(() {});
    } on CameraException catch (e) {
      if (mounted) setState(() => _error = '카메라를 사용할 수 없어요 (${e.description ?? e.code}).\n설정에서 카메라 권한을 허용해 주세요.');
    }
  }

  Future<void> _stopCamera() async {
    final controller = _camera;
    _camera = null;
    if (controller == null) return;
    try {
      if (controller.value.isStreamingImages) await controller.stopImageStream();
      await controller.dispose();
    } catch (_) {}
  }

  /// 소리 안내 켜기/끄기 (둘 다 켜져 있으면 모두 끔, 하나라도 꺼져 있으면 모두 켬)
  void _toggleAlerts() {
    final profile = context.read<ProfileProvider>();
    final on = !(profile.user.voiceEnabled && profile.user.soundEnabled);
    profile.setVoice(on);
    profile.setSound(on);
    _alert.voiceEnabled = on;
    _alert.soundEnabled = on;
    if (!on) _alert.stop();
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(on ? '오류 소리 안내를 켰어요' : '오류 소리 안내를 껐어요'),
      duration: const Duration(seconds: 1),
    ));
  }

  Future<void> _switchCamera() async {
    if (_cameras.length < 2) return;
    await _stopCamera();
    setState(() {
      _poses = [];
      _cameraIndex = (_cameraIndex + 1) % _cameras.length;
    });
    context.read<SessionProvider>().controller?.restartCalibration();
    await _startCamera();
  }

  // ---------------- 프레임 ----------------

  Future<void> _onFrame(CameraImage image) async {
    final session = context.read<SessionProvider>();
    final workout = session.controller;
    final camera = _camera;
    if (_busy || _leaving || session.paused || workout == null || camera == null) return;
    _busy = true;
    try {
      final input = cameraImageToInputImage(image, _cameras[_cameraIndex], camera);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted || _leaving || session.paused) return;
      final meta = input.metadata!;
      final now = DateTime.now();
      final upright = uprightImageSize(meta.size, meta.rotation);

      // 처음 잡을 때는 엄격하게(어깨~발목이 화면 높이의 30% 이상), 잡은 뒤에는 느슨하게(12% 이상)
      final tracking = _personFrames >= _personFramesNeeded;
      final isPerson = poses.isNotEmpty && looksLikePerson(poses.first, upright, minBodyRatio: tracking ? 0.12 : 0.3);
      if (isPerson) {
        _personFrames++;
        _missedFrames = 0;
      } else if (tracking && _missedFrames < _maxMissedFrames) {
        _missedFrames++;
      } else {
        _personFrames = 0;
        _missedFrames = 0;
      }
      final personReady = poses.isNotEmpty && _personFrames >= _personFramesNeeded;

      final wasCalibrating = workout.phase == WorkoutPhase.calibrating;
      final repDone = workout.onFrame(personReady ? poses.first : null, upright, now);

      _alertForErrors(workout, repDone);

      // 영점 조절 중 12초 넘게 몸을 못 찾으면 "인식 실패" 안내 화면
      if (workout.phase == WorkoutPhase.calibrating && !workout.bodyVisible) {
        _noBodySince ??= now;
        if (now.difference(_noBodySince!) > const Duration(seconds: 12)) {
          _noBodySince = null;
          _showRecognitionFail();
        }
      } else {
        _noBodySince = null;
      }

      if (repDone) {
        HapticFeedback.mediumImpact();
        if (session.onRepCompleted()) {
          _onSetCompleted();
        }
      }
      if (wasCalibrating && workout.phase == WorkoutPhase.active) HapticFeedback.lightImpact();

      setState(() {
        _poses = personReady ? poses : [];
        _imageSize = meta.size;
        _rotation = meta.rotation;
      });
    } catch (e) {
      debugPrint('analysis frame error: $e');
    } finally {
      _busy = false;
    }
  }

  /// 소리 안내: 정자세 횟수 읽기 + 오류 경고음/음성. 화면 문구는 실시간으로 바뀌지만 소리는 규칙대로만 냅니다:
  /// 앉아 있는 중 "오류" 단계가 되면 바로 한 번, 1회가 끝났을 때 아직 안 알린 오류가 있으면 한 번.
  void _alertForErrors(WorkoutController w, bool repDone) {
    if (w.phase == WorkoutPhase.active) {
      final live = w.tracker?.liveFault;
      if (w.isDown && live != null && w.tracker!.liveLevel == Level.error && _alertedThisRep.add(live)) {
        _alert.alert(live);
      }
      final last = w.lastRep;
      if (repDone && last != null && last.isGood) {
        _alert.countRep(w.currentGood); // 정자세일 때만 "하나, 둘…" 하고 센다 (오류 난 회는 세지 않음)
      }
      if (repDone && last != null && !last.isGood) {
        for (final f in last.faults) {
          if (_alertedThisRep.add(f)) {
            _alert.alert(f);
            break; // 한 번에 하나만 (가장 앞 오류)
          }
        }
      }
    }
    if (repDone || !w.isDown) _alertedThisRep.clear();
  }

  // ---------------- 세트 / 운동 종료 ----------------

  /// 인식 실패 안내. "다시 인식하기"(또는 5초 뒤 자동)면 영점 조절을 다시 시작, X 를 누르면 운동 취소
  Future<void> _showRecognitionFail() async {
    if (_leaving || !mounted) return;
    _leaving = true;
    final retry = await Navigator.of(context).pushNamed<bool>('/recognition-fail');
    if (!mounted) return;
    if (retry == true) {
      context.read<SessionProvider>().controller?.restartCalibration();
      _noBodySince = null;
      _leaving = false;
    } else {
      context.read<SessionProvider>().cancel();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    }
  }

  /// 분석 화면 위에 [builder]가 만든 화면을 겹쳐 보여주고, 그 화면이 done(값)을 부르면 닫고 값을 돌려줍니다.
  Future<bool> _showOverlay(Widget Function(void Function(bool) done) builder) {
    final completer = Completer<bool>();
    void done(bool v) {
      if (completer.isCompleted) return;
      if (mounted) setState(() => _overlay = null);
      completer.complete(v);
    }

    setState(() => _overlay = builder(done));
    return completer.future;
  }

  /// 3-2-1 카운트다운. 끝까지 보면 true, 닫기(X)를 누르면 운동을 취소하고 홈으로 갑니다.
  Future<bool> _runCountdown() async {
    if (!mounted) return false;
    _leaving = true; // 카운트다운 동안은 판정하지 않음
    final ok = await _showOverlay((done) => CountdownScreen(onDone: done));
    if (!mounted) return false;
    if (ok != true) {
      context.read<SessionProvider>().cancel();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      return false;
    }
    _leaving = false;
    return true;
  }

  /// 세트가 끝난 뒤: 마지막 세트면 저장하고 결과로, 아니면 휴식 → 카운트다운 → 다음 세트(영점 조절)
  Future<void> _onSetCompleted() async {
    if (_leaving || !mounted) return;
    final session = context.read<SessionProvider>();
    if (session.allSetsDone) {
      await _finishWorkout();
      return;
    }
    _leaving = true;
    try {
      // 휴식 화면(설정한 휴식 시간)을 화면 위에 겹쳐 보여줍니다: "바로 시작"/시간 종료 → true, "운동 끝내기" → false
      final next = await _showOverlay((done) => RestBetweenSetsScreen(onDone: done));
      if (!mounted) return;
      if (next == false) {
        _leaving = false;
        await _finishWorkout();
        return;
      }
      if (!await _runCountdown()) return; // 닫기를 눌렀다면 이미 홈으로 이동함
      session.startNextSet();
      setState(() => _poses = []);
    } catch (e) {
      debugPrint('다음 세트 전환 실패: $e');
      if (mounted) session.startNextSet();
    } finally {
      _leaving = false;
    }
  }

  Future<void> _finishWorkout() async {
    if (!mounted) return;
    final session = context.read<SessionProvider>();
    if (!session.hasAnyReps) {
      session.cancel();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
      return;
    }
    _leaving = true;
    try {
      await session.finishAndSave(); // 저장 후 DB에서 다시 읽어 값 확인
    } catch (e) {
      debugPrint('저장 실패: $e');
      _leaving = false;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('저장에 실패했어요. 기록은 남아 있으니 다시 눌러 주세요')));
      return;
    }
    await _stopCamera();
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed('/result');
  }

  void _endSetButton() {
    final session = context.read<SessionProvider>();
    if (session.repsInSet == 0) {
      _confirmEndWithoutReps();
      return;
    }
    if (session.completeSet()) {
      _finishWorkout();
    } else {
      _onSetCompleted();
    }
  }

  /// 이번 세트에 센 횟수가 없을 때: 운동을 끝낼지 묻는다 (이전 세트 기록이 있으면 저장)
  Future<void> _confirmEndWithoutReps() async {
    final session = context.read<SessionProvider>();
    session.pause();
    final end = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('운동을 종료할까요?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: Text(
          session.hasAnyReps ? '이번 세트에서 센 횟수가 없어요. 앞선 세트까지의 기록을 저장해요.' : '아직 센 횟수가 없어요. 기록 없이 종료해요.',
          style: const TextStyle(fontSize: 12.5),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('계속하기')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('종료', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    session.resume();
    if (end == true) await _finishWorkout();
  }

  Future<void> _pause() async {
    final session = context.read<SessionProvider>();
    session.pause();
    _alert.stop();
    final action = await Navigator.of(context).pushNamed<PauseAction>('/paused');
    if (!mounted) return;
    if (action == PauseAction.restartSet) {
      session.restartCurrentSet();
      setState(() => _poses = []);
    } else if (action == PauseAction.end) {
      session.resume();
      await _finishWorkout();
    } else if (action == PauseAction.exitHome) {
      session.cancel(); // 저장하지 않고 홈으로
      await _stopCamera();
      if (!mounted) return;
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
    } else {
      session.resume();
    }
  }

  Future<void> _confirmLeave(AppTab tab) async {
    final session = context.read<SessionProvider>();
    session.pause();
    final leave = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('운동을 종료할까요?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: const Text('지금까지의 기록은 저장되지 않아요.', style: TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('계속하기')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('종료', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (!mounted) return;
    if (leave == true) {
      session.cancel();
      Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false, arguments: tab);
    } else {
      session.resume();
    }
  }

  // ---------------- 화면 ----------------

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();
    final workout = session.controller;

    return Stack(
      children: [
        Positioned.fill(child: _analysisPage(session, workout)),
        if (_overlay != null) Positioned.fill(child: _overlay!),
      ],
    );
  }

  Widget _analysisPage(SessionProvider session, WorkoutController? workout) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ScreenHeader(
                title: '운동 분석',
                onBack: _pause,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RoundIconButton(
                      icon: (context.watch<ProfileProvider>().user.voiceEnabled ||
                              context.watch<ProfileProvider>().user.soundEnabled)
                          ? Icons.volume_up_rounded
                          : Icons.volume_off_rounded,
                      onTap: _toggleAlerts,
                    ),
                    if (_cameras.length > 1) ...[
                      const SizedBox(width: 8),
                      RoundIconButton(icon: Icons.cameraswitch_outlined, onTap: _switchCamera),
                    ],
                  ],
                ),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Expanded(child: _cameraCard(session, workout)),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        Expanded(
                          child: StatTile(
                            value: session.repsInSet == 0 ? '-' : '${session.accuracy}',
                            unit: session.repsInSet == 0 ? '' : '%',
                            label: '현재 세트 정확도',
                            valueColor: AppColors.primary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(child: StatTile(value: '${session.currentGood}', unit: '회', label: '정자세')),
                        const SizedBox(width: 8),
                        Expanded(child: StatTile(value: mmss(session.elapsedSeconds), label: '경과 시간')),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      children: [
                        RoundIconButton(icon: Icons.pause_rounded, size: 52, onTap: _pause),
                        const SizedBox(width: 10),
                        Expanded(
                          child: PrimaryButton(
                            label: '세트 종료',
                            color: AppColors.danger,
                            icon: Icons.stop_rounded,
                            onPressed: _endSetButton,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                  ],
                ),
              ),
            ),
            BottomNavBar(current: AppTab.workout, onTap: _confirmLeave),
          ],
        ),
      ),
    );
  }

  Widget _cameraCard(SessionProvider session, WorkoutController? workout) {
    final camera = _camera;
    Widget preview;
    if (_error != null) {
      preview = Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!,
              textAlign: TextAlign.center, style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.5)),
        ),
      );
    } else if (camera == null || !camera.value.isInitialized) {
      preview = const Center(child: CircularProgressIndicator(color: Colors.white70));
    } else {
      preview = Center(
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

    final banner = workout == null ? null : _bannerFor(workout);

    return Container(
      decoration: BoxDecoration(gradient: AppColors.cameraGradient, borderRadius: BorderRadius.circular(24)),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          Positioned.fill(child: preview),
          Positioned(
            top: 12,
            left: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('반복 횟수', style: TextStyle(color: Colors.white60, fontSize: 9)),
                  RichText(
                    text: TextSpan(
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18),
                      children: [
                        TextSpan(text: '${session.repsInSet}'),
                        TextSpan(
                          text: ' / ${session.targetRepsPerSet}',
                          style: const TextStyle(color: AppColors.accentMint, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            top: 12,
            right: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(color: Colors.black45, borderRadius: BorderRadius.circular(12)),
              child: Text('${session.currentSet}세트 · ${session.judgeMode.label}',
                  style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
            ),
          ),
          if (banner != null)
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: AnimatedSwitcher(
                duration: const Duration(milliseconds: 200),
                child: Container(
                  key: ValueKey('${banner.title}|${banner.sub}'),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                  decoration: BoxDecoration(color: const Color(0xFFF1F3EF), borderRadius: BorderRadius.circular(12)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Icon(banner.icon, size: 20, color: banner.color),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(banner.title,
                                    style: const TextStyle(
                                        fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                                const SizedBox(height: 1),
                                Text(banner.sub,
                                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.35)),
                              ],
                            ),
                          ),
                        ],
                      ),
                      if (banner.progress != null) ...[
                        const SizedBox(height: 8),
                        ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: banner.progress,
                            minHeight: 6,
                            color: AppColors.primary,
                            backgroundColor: AppColors.ringTrack,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  /// 지금 상태에 맞는 안내 문구 (영점 조절 / 전신 안 보임 / 방금 1회 결과 / 실시간 오류 / 준비 완료)
  _Banner _bannerFor(WorkoutController w) {
    final now = DateTime.now();
    switch (w.phase) {
      case WorkoutPhase.calibrating:
        final issue = w.calibrationIssue;
        return _Banner(
          icon: Icons.accessibility_new_rounded,
          color: issue == null ? AppColors.primary : AppColors.warningYellow,
          title: '영점 조절 중',
          sub: issue ?? '정면을 보고 똑바로 서서 2초만 기다려 주세요',
          progress: w.calibrationProgress(now),
        );
      case WorkoutPhase.resting:
        return const _Banner(
          icon: Icons.self_improvement_rounded,
          color: AppColors.textMuted,
          title: '세트 완료',
          sub: '숨을 고르고 다음 세트를 시작하세요',
        );
      case WorkoutPhase.active:
        if (!w.bodyVisible) {
          return const _Banner(
            icon: Icons.crop_free_rounded,
            color: AppColors.warningYellow,
            title: '전신이 보이지 않아요',
            sub: '머리부터 발끝까지 화면에 들어오게 서 주세요',
          );
        }
        final last = w.lastRep;
        final lastAt = w.lastRepAt;
        if (last != null &&
            lastAt != null &&
            now.difference(lastAt) < const Duration(milliseconds: 1500) &&
            !w.isDown) {
          if (last.isGood) {
            return _Banner(
              icon: Icons.check_circle_rounded,
              color: AppColors.primary,
              title: '${w.currentReps.length}회 · 정자세!',
              sub: last.warnings.isEmpty ? '좋아요, 그대로 계속하세요' : '참고: ${last.warnings.first.feedback}',
            );
          }
          final main = last.faults.first;
          return _Banner(
            icon: Icons.error_rounded,
            color: AppColors.danger,
            title: '${w.currentReps.length}회 · ${main.label}',
            sub: main.feedback,
          );
        }
        final live = w.tracker?.liveFault;
        if (w.isDown && live != null) {
          final isError = w.tracker!.liveLevel == Level.error;
          return _Banner(
            icon: isError ? Icons.error_rounded : Icons.warning_amber_rounded,
            color: isError ? AppColors.danger : AppColors.warningYellow,
            title: live.label + (live.role == CheckRole.reference ? ' (참고)' : ''),
            sub: live.feedback,
          );
        }
        return _Banner(
          icon: Icons.check_circle_rounded,
          color: AppColors.primary,
          title: w.isDown ? '좋아요, 그대로!' : '준비 완료',
          sub: w.isDown ? '천천히 일어서세요' : '천천히 앉았다 일어서면 1회로 세요',
        );
    }
  }
}

class _Banner {
  const _Banner({required this.icon, required this.color, required this.title, required this.sub, this.progress});
  final IconData icon;
  final Color color;
  final String title;
  final String sub;
  final double? progress;
}
