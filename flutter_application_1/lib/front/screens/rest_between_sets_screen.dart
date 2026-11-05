import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/primary_button.dart';
import '../widgets/segmented_ring.dart';

/// 세트 사이 휴식 (Figma: 세트 마다 휴식)
class RestBetweenSetsScreen extends StatefulWidget {
  const RestBetweenSetsScreen({super.key, this.onDone});

  /// 운동 분석 화면 위에 겹쳐 보여줄 때 쓰는 콜백 (true: 다음 세트 시작, false: 운동 끝내기). 없으면 화면을 닫으며 결과를 돌려줍니다.
  final void Function(bool next)? onDone;

  @override
  State<RestBetweenSetsScreen> createState() => _RestBetweenSetsScreenState();
}

class _RestBetweenSetsScreenState extends State<RestBetweenSetsScreen> {
  late int _total = context.read<SessionProvider>().restSeconds;
  late int _remaining = _total;
  late DateTime _endAt = DateTime.now().add(Duration(seconds: _total)); // 끝나는 시각 기준으로 계산 (누락 없이 정확하게)
  Timer? _timer;
  bool _leaving = false;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      final left = _endAt.difference(DateTime.now()).inMilliseconds;
      if (left <= 0) {
        t.cancel();
        _next(); // 휴식 시간이 다 지나면 다음 세트 카운트다운으로
        return;
      }
      final sec = (left / 1000).ceil();
      if (sec != _remaining) setState(() => _remaining = sec);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _next() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    if (widget.onDone != null) {
      widget.onDone!(true);
    } else {
      Navigator.of(context).pop(true); // 운동 분석 화면이 다음 세트(영점 조절)를 시작합니다
    }
  }

  void _endWorkout() {
    if (_leaving || !mounted) return;
    _leaving = true;
    _timer?.cancel();
    if (widget.onDone != null) {
      widget.onDone!(false);
    } else {
      Navigator.of(context).pop(false); // 운동 분석 화면이 지금까지 기록을 저장하고 결과로 이동
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.read<SessionProvider>();
    final last = s.lastSetRecord;
    final progress = _total == 0 ? 0.0 : _remaining / _total;
    final good = (last?.accuracy ?? 0) >= 85;

    return PopScope(
      canPop: false, // 뒤로가기로 휴식을 건너뛰지 않음 (바로 시작 / 운동 끝내기 버튼만 사용)
      child: Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerRight,
                child: IconButton(onPressed: _endWorkout, icon: const Icon(Icons.close_rounded, color: AppColors.textDark)),
              ),
              const SizedBox(height: 8),
              Text('${s.currentSet}세트 완료!',
                  style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 6),
              const Text('잠깐 쉬고 다음 세트를 준비해요', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 28),
              SizedBox(
                width: 220,
                height: 220,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    TweenAnimationBuilder<double>(
                      tween: Tween(begin: 1, end: progress),
                      duration: const Duration(milliseconds: 500),
                      builder: (context, v, _) => SegmentedRing(
                        size: 220,
                        progress: v,
                        color: AppColors.primary,
                        trackColor: AppColors.ringTrack,
                        strokeWidth: 14,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(mmss(_remaining),
                            style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        const Text('남은 휴식', style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 26),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('방금 세트', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                          const SizedBox(height: 2),
                          Text('정확도 ${last?.accuracy.round() ?? 0}% · ${last?.reps ?? 0}회',
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: good ? AppColors.primarySoft : AppColors.warningBg,
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(good ? '좋아요' : '보통',
                          style: TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: good ? AppColors.primary : AppColors.warningText,
                          )),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              SoftCard(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('다음', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    const SizedBox(height: 2),
                    Text('${s.currentSet + 1}세트 · ${s.targetRepsPerSet}회',
                        style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
              ),
              const Spacer(),
              Row(
                children: [
                  Expanded(
                    child: PrimaryButton(
                      label: '+10초',
                      filled: false,
                      onPressed: () => setState(() {
                        _endAt = _endAt.add(const Duration(seconds: 10));
                        _remaining += 10;
                        _total += 10;
                      }),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(flex: 2, child: PrimaryButton(label: '바로 시작', onPressed: _next)),
                ],
              ),
              const SizedBox(height: 4),
              TextButton(
                onPressed: _endWorkout,
                child: const Text('운동 끝내기',
                    style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700)),
              ),
              const SizedBox(height: 12),
            ],
          ),
        ),
      ),
    ));
  }
}
