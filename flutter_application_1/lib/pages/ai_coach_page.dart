import 'dart:collection';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../ai/squat_classifier.dart';
import '../ai/squat_features.dart';
import '../ai/squat_rep_tracker.dart';
import '../camera/input_image_util.dart';
import '../db/app_database.dart';
import '../models/user.dart';
import '../models/workout_session.dart';
import '../pose_painter.dart';
import '../ui/app_colors.dart';

/// 화면 위쪽에 보여줄 상태
enum _Phase { noPerson, notFullBody, standing, judging }

/// 실시간 AI 스쿼트 코치 (시연용)
/// 카메라 → ML Kit 관절 → 12개 특징 → 팀 모델(6가지 자세) → 반복별 판정 → DB 저장
class AiCoachPage extends StatefulWidget {
  const AiCoachPage({super.key});

  @override
  State<AiCoachPage> createState() => _AiCoachPageState();
}

class _AiCoachPageState extends State<AiCoachPage> with WidgetsBindingObserver {
  final _detector = PoseDetector(
    options: PoseDetectorOptions(
      mode: PoseDetectionMode.stream,
      model: PoseDetectionModel.base,
    ),
  );
  final _classifier = const SquatClassifier();
  final _tracker = SquatRepTracker();

  List<CameraDescription> _cameras = [];
  CameraController? _controller;
  int _cameraIndex = 0;
  bool _busy = false;
  String? _error;

  // 화면 표시용
  List<Pose> _poses = [];
  Size? _imageSize;
  InputImageRotation _rotation = InputImageRotation.rotation0deg;
  _Phase _phase = _Phase.noPerson;
  double? _kneeAngle;
  List<double> _probs = List.filled(SquatClass.values.length, 0);
  final Queue<List<double>> _recentProbs = Queue(); // 깜빡임 방지용 평균

  // 피드백 지연 측정
  static const _smoothFrames = 4; // 화면 판정 평균 프레임 수 (6 → 4: 반응 빠르게)
  double _procMs = 0; // 프레임 1장 분석 시간 (ML Kit + 각도 계산 + 모델), 이동 평균
  double _fps = 0; // 1초에 분석이 끝나는 프레임 수
  int _fpsCount = 0;
  DateTime _fpsStart = DateTime.now();

  /// 피드백 지연(추정) = 분석 시간 + 평균 내는 동안 밀리는 시간(평균 프레임의 절반)
  double get _feedbackDelayMs =>
      _fps <= 0 ? 0 : _procMs + (_smoothFrames / 2) * (1000 / _fps);
  RepResult? _lastRep;
  bool _showProbs = false;
  bool _saving = false;

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
    _detector.close();
    super.dispose();
  }

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

  // ---------------- 카메라 ----------------

  Future<void> _initCameras() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        setState(() => _error = '사용 가능한 카메라가 없습니다.');
        return;
      }
      final front = _cameras
          .indexWhere((c) => c.lensDirection == CameraLensDirection.front);
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

  // ---------------- 프레임 분석 ----------------

  Future<void> _onFrame(CameraImage image) async {
    if (_busy) return;
    final controller = _controller;
    if (controller == null) return;
    _busy = true;
    final t0 = DateTime.now();
    try {
      final input =
          cameraImageToInputImage(image, _cameras[_cameraIndex], controller);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      if (!mounted) return;

      final meta = input.metadata!;
      var phase = _Phase.noPerson;
      double? knee;
      RepResult? finished;

      if (poses.isNotEmpty) {
        final frame = extractSquatFrame(
            poses.first, uprightImageSize(meta.size, meta.rotation));
        if (frame == null) {
          phase = _Phase.notFullBody;
        } else {
          knee = frame.kneeAngle2d;
          final probs = _classifier.predict(frame.features);
          finished = _tracker.update(knee, probs, DateTime.now());

          if (knee < _tracker.judgeBelow) {
            phase = _Phase.judging;
            _recentProbs.addLast(probs);
            while (_recentProbs.length > _smoothFrames) {
              _recentProbs.removeFirst();
            }
            _probs = _averaged();
          } else {
            phase = _Phase.standing;
            _recentProbs.clear();
          }
        }
      }

      if (finished != null) {
        HapticFeedback.mediumImpact();
      }

      // 분석 시간 (값이 튀지 않게 이동 평균)
      final ms = DateTime.now().difference(t0).inMicroseconds / 1000;
      _procMs = _procMs == 0 ? ms : _procMs * 0.9 + ms * 0.1;
      // 분석 FPS (1초마다 갱신) + 터미널 로그
      _fpsCount++;
      final elapsed = DateTime.now().difference(_fpsStart).inMilliseconds;
      if (elapsed >= 1000) {
        _fps = _fpsCount * 1000 / elapsed;
        _fpsCount = 0;
        _fpsStart = DateTime.now();
        debugPrint('[지연] 분석 ${_procMs.toStringAsFixed(0)}ms · '
            '${_fps.toStringAsFixed(1)}fps · 피드백 약 ${_feedbackDelayMs.toStringAsFixed(0)}ms');
      }

      setState(() {
        _poses = poses;
        _imageSize = meta.size;
        _rotation = meta.rotation;
        _phase = phase;
        _kneeAngle = knee;
        if (finished != null) _lastRep = finished;
      });
    } catch (e) {
      debugPrint('AI coach error: $e');
    } finally {
      _busy = false;
    }
  }

  List<double> _averaged() {
    final sum = List<double>.filled(SquatClass.values.length, 0);
    for (final p in _recentProbs) {
      for (var i = 0; i < p.length; i++) {
        sum[i] += p[i];
      }
    }
    return sum.map((v) => v / _recentProbs.length).toList();
  }

  // ---------------- 세트 저장 ----------------

  Future<int> _userIdForSaving() async {
    final db = AppDatabase.instance;
    final users = await db.getAllUsers();
    if (users.isNotEmpty) return users.first.id!;
    return db.insertUser(User(
      name: '나',
      age: 25,
      heightCm: 170,
      weightKg: 65,
      createdAt: DateTime.now(),
    ));
  }

  Future<void> _saveSet() async {
    final reps = List<RepResult>.from(_tracker.reps);
    if (reps.isEmpty || _saving) return;
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final start = _tracker.firstRepStartedAt ?? reps.first.endedAt;
      final end = reps.last.endedAt;
      final avgScore = reps.fold<double>(0, (a, r) => a + r.score) / reps.length;
      final seconds = end.difference(start).inSeconds;
      final good = reps.where((r) => r.isGood).length;
      final userId = await _userIdForSaving();
      final db = AppDatabase.instance;

      final id = await db.insertSession(WorkoutSession(
        userId: userId,
        exerciseType: 'squat',
        startedAt: start,
        durationSec: seconds < 1 ? 1 : seconds,
        totalReps: reps.length,
        goodReps: good,
        averageScore: avgScore,
        memo: _tracker.faultSummary(),
      ));

      // 저장한 기록을 DB에서 다시 읽어서 값이 맞는지 확인
      final saved = (await db.getSessionsByUser(userId)).where((s) => s.id == id);
      if (saved.isEmpty ||
          saved.first.totalReps != reps.length ||
          saved.first.goodReps != good) {
        throw Exception('저장한 값과 DB 값이 다릅니다 (id: $id)');
      }

      _tracker.reset(); // 저장이 확인된 뒤에만 지움
      if (!mounted) return;
      setState(() => _lastRep = null);
      messenger.showSnackBar(SnackBar(
        content: Text('✅ 저장 확인: ${reps.length}회 중 $good회 정자세 · 마이페이지에서 볼 수 있어요'),
      ));
    } catch (e) {
      // 실패하면 기록을 지우지 않고 남겨 둠 → 다시 저장을 누를 수 있음
      debugPrint('세트 저장 실패: $e');
      messenger.showSnackBar(SnackBar(
        backgroundColor: AppColors.serious,
        duration: const Duration(seconds: 5),
        content: Text('저장에 실패했어요. 기록은 남아 있으니 다시 눌러 주세요.\n$e'),
      ));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  /// 저장 안 한 반복이 있으면 나가기 전에 물어봄
  Future<void> _confirmLeave() async {
    final choice = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('저장하지 않은 기록이 있어요'),
        content: Text('${_tracker.reps.length}회를 저장할까요?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, 'discard'), child: const Text('저장 안 함')),
          TextButton(onPressed: () => Navigator.pop(ctx, 'stay'), child: const Text('계속하기')),
          FilledButton(onPressed: () => Navigator.pop(ctx, 'save'), child: const Text('저장하고 나가기')),
        ],
      ),
    );
    if (!mounted || choice == null || choice == 'stay') return;
    if (choice == 'save') {
      await _saveSet();
      if (_tracker.reps.isNotEmpty) return; // 저장 실패 → 화면에 남음
    } else {
      _tracker.reset();
    }
    if (mounted) Navigator.pop(context);
  }

  void _resetSet() {
    _tracker.reset();
    setState(() => _lastRep = null);
  }

  // ---------------- 화면 ----------------

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return const Scaffold(
        backgroundColor: Colors.black,
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return PopScope(
      canPop: _tracker.reps.isEmpty, // 저장할 기록이 없을 때만 바로 나감
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) _confirmLeave();
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
                _topBar(),
                _statusBanner(),
                if (_showProbs) _probPanel(),
                const Spacer(),
                _bottomPanel(),
              ],
            ),
          ),
        ],
      ),
    ),
    );
  }

  Widget _roundButton(IconData icon, String tooltip, VoidCallback onTap,
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

  Widget _topBar() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(8, 8, 12, 0),
      child: Row(
        children: [
          Material(
            color: Colors.black54,
            shape: const CircleBorder(),
            child: IconButton(
              tooltip: '뒤로',
              onPressed: () => Navigator.maybePop(context),
              icon: const Icon(Icons.arrow_back, color: Colors.white),
            ),
          ),
          const SizedBox(width: 10),
          const Expanded(
            child: Text(
              'AI 스쿼트 코치',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w700,
                shadows: [Shadow(blurRadius: 6, color: Colors.black)],
              ),
            ),
          ),
          _roundButton(Icons.analytics_outlined, 'AI 확률 보기',
              () => setState(() => _showProbs = !_showProbs),
              active: _showProbs),
          if (_cameras.length > 1)
            _roundButton(Icons.cameraswitch, '카메라 전환', _switchCamera),
        ],
      ),
    );
  }

  Widget _statusBanner() {
    final (IconData icon, Color color, String title, String sub) =
        switch (_phase) {
      _Phase.noPerson => (
          Icons.person_search,
          AppColors.textMuted,
          '사람을 찾는 중',
          '카메라에서 2~3m 떨어져 서 주세요',
        ),
      _Phase.notFullBody => (
          Icons.crop_free,
          AppColors.warning,
          '전신이 보이지 않아요',
          '머리부터 발끝까지 화면에 들어오게 서 주세요',
        ),
      _Phase.standing => (
          Icons.accessibility_new,
          AppColors.textSecondary,
          '준비 완료',
          '천천히 앉아 보세요. 앉는 동안 자세를 판정해요',
        ),
      _Phase.judging => () {
          final c = topClass(_probs);
          final good = c == SquatClass.normal;
          return (
            good ? Icons.check_circle : Icons.error,
            good ? AppColors.good : AppColors.serious,
            c.label,
            c.feedback,
          );
        }(),
    };

    return Container(
      margin: const EdgeInsets.fromLTRB(12, 12, 12, 0),
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      decoration: BoxDecoration(
        color: const Color(0xD9242422),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withAlpha(160), width: 1.5),
      ),
      child: Row(
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
                    style: const TextStyle(
                        fontSize: 13.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _probPanel() {
    final judging = _phase == _Phase.judging;
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
            '분석 ${_procMs.toStringAsFixed(0)}ms · ${_fps.toStringAsFixed(1)}fps · '
            '피드백 지연 약 ${(_feedbackDelayMs / 1000).toStringAsFixed(2)}초',
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
                        style: const TextStyle(
                            fontSize: 12, color: AppColors.textSecondary)),
                  ),
                  Expanded(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: judging ? _probs[c.index] : 0,
                        minHeight: 7,
                        color: AppColors.series,
                        backgroundColor: AppColors.grid,
                      ),
                    ),
                  ),
                  SizedBox(
                    width: 40,
                    child: Text(
                      judging
                          ? '${(_probs[c.index] * 100).toStringAsFixed(0)}%'
                          : '-',
                      textAlign: TextAlign.right,
                      style: const TextStyle(
                          fontSize: 12, color: AppColors.textPrimary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Widget _bottomPanel() {
    final reps = _tracker.reps.length;
    final good = _tracker.goodCount;
    final last = _lastRep;

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
      decoration: BoxDecoration(
        color: const Color(0xE6242422),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              _bigStat('횟수', '$reps', '회'),
              _bigStat('정자세', '$good', '회'),
              _bigStat('무릎 각도',
                  _kneeAngle == null ? '-' : _kneeAngle!.round().toString(), '°'),
            ],
          ),
          if (last != null) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                children: [
                  Icon(last.isGood ? Icons.check_circle : Icons.error,
                      size: 18,
                      color: last.isGood ? AppColors.good : AppColors.serious),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      '${last.index}회차 · ${last.verdict.label}',
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  Text('${last.score.toStringAsFixed(0)}점',
                      style: const TextStyle(
                          fontSize: 14, color: AppColors.textSecondary)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: reps == 0 ? null : _resetSet,
                  icon: const Icon(Icons.refresh),
                  label: const Text('다시 하기'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton.icon(
                  onPressed: reps == 0 || _saving ? null : _saveSet,
                  icon: const Icon(Icons.save_alt),
                  label: const Text('세트 저장'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
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
              style:
                  const TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
          ])),
          Text(label,
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
