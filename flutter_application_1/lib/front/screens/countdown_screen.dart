import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/figure_painter.dart';
import '../widgets/segmented_ring.dart';

/// 시작 카운트다운 (Figma: 시작 카운트다운).
/// 3 → 2 → 1 로 숫자가 바뀔 때마다 숫자가 크게 나타나며 줄어들고(스케일+페이드),
/// 노란 4조각 링이 1/4바퀴씩 돌아갑니다.
/// 첫 시작과 휴식 후 다음 세트 시작 때 운동 분석 화면이 띄우며, 끝나면 true(취소하면 false)를 돌려줍니다.
class CountdownScreen extends StatefulWidget {
  const CountdownScreen({super.key, this.onDone});

  /// 화면 위에 겹쳐 보여줄 때 쓰는 콜백 (끝나면 true, 닫기(X)면 false). 없으면 화면을 닫으며 결과를 돌려줍니다.
  final void Function(bool completed)? onDone;

  @override
  State<CountdownScreen> createState() => _CountdownScreenState();
}

class _CountdownScreenState extends State<CountdownScreen> {
  int _count = 3;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (_count <= 1) {
        timer.cancel();
        if (widget.onDone != null) {
          widget.onDone!(true);
        } else {
          Navigator.of(context).pop(true); // 운동 분석 화면이 이어서 영점 조절을 시작합니다
        }
        return;
      }
      setState(() => _count -= 1);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _close() {
    _timer?.cancel();
    if (widget.onDone != null) {
      widget.onDone!(false);
    } else {
      Navigator.of(context).pop(false); // 운동 분석 화면이 운동을 취소하고 홈으로 돌아갑니다
    }
  }

  @override
  Widget build(BuildContext context) {
    final session = context.watch<SessionProvider>();

    return Scaffold(
      backgroundColor: AppColors.pageDark,
      body: SafeArea(
        child: Stack(
          children: [
            // 배경의 흐릿한 사람 실루엣
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(90, 140, 90, 240),
                child: Opacity(opacity: 0.35, child: DimFigure()),
              ),
            ),
            Align(
              alignment: Alignment.topRight,
              child: IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded, color: Colors.white)),
            ),
            Align(
              alignment: Alignment.topCenter,
              child: Container(
                margin: const EdgeInsets.only(top: 14),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(color: const Color(0xFF2A332F), borderRadius: BorderRadius.circular(16)),
                child: Text('${session.upcomingSet}세트 · ${session.targetRepsPerSet}회',
                    style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w700)),
              ),
            ),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 190,
                    height: 190,
                    child: Stack(
                      alignment: Alignment.center,
                      children: [
                        AnimatedRotation(
                          turns: (3 - _count) * 0.25,
                          duration: const Duration(milliseconds: 600),
                          curve: Curves.easeOutBack,
                          child: const SegmentedRing(
                            size: 190,
                            progress: 1,
                            color: AppColors.warningYellow,
                            trackColor: AppColors.warningYellow,
                            strokeWidth: 6,
                          ),
                        ),
                        Container(
                          width: 168,
                          height: 168,
                          decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                          alignment: Alignment.center,
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 450),
                            switchInCurve: Curves.easeOutBack,
                            switchOutCurve: Curves.easeIn,
                            transitionBuilder: (child, animation) {
                              final scale = Tween<double>(begin: 1.8, end: 1.0).animate(animation);
                              return FadeTransition(opacity: animation, child: ScaleTransition(scale: scale, child: child));
                            },
                            child: Text(
                              '$_count',
                              key: ValueKey(_count),
                              style: const TextStyle(color: Colors.white, fontSize: 80, fontWeight: FontWeight.w800),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 22),
                  const Text('곧 시작해요', style: TextStyle(color: Colors.white, fontSize: 19, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 6),
                  const Text('정면으로 서서 준비 자세를 잡아 주세요',
                      style: TextStyle(color: Colors.white60, fontSize: 11.5)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
