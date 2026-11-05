import 'dart:async';

import 'package:flutter/material.dart';

import '../theme/app_theme.dart';
import '../widgets/dashed_frame.dart';
import '../widgets/figure_painter.dart';

/// 인식 실패 (Figma: 인식실패) — 몸 전체가 보이지 않을 때의 안내.
class RecognitionFailScreen extends StatefulWidget {
  const RecognitionFailScreen({super.key});

  @override
  State<RecognitionFailScreen> createState() => _RecognitionFailScreenState();
}

class _RecognitionFailScreenState extends State<RecognitionFailScreen> {
  Timer? _autoRetry;

  @override
  void initState() {
    super.initState();
    // "자동으로 다시 인식하고 있어요..." — 5초 뒤 자동으로 영점 조절을 다시 시도합니다.
    _autoRetry = Timer(const Duration(seconds: 5), _retry);
  }

  @override
  void dispose() {
    _autoRetry?.cancel();
    super.dispose();
  }

  void _retry() {
    if (!mounted) return;
    _autoRetry?.cancel();
    Navigator.of(context).pop(true); // 운동 분석 화면이 영점 조절을 다시 시작합니다
  }

  void _close() {
    _autoRetry?.cancel();
    Navigator.of(context).pop(false); // 운동 분석 화면이 운동을 취소하고 홈으로 돌아갑니다
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.screenDark,
      body: SafeArea(
        child: Column(
          children: [
            SizedBox(
              height: 52,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  const Text('자세 분석', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(onPressed: _close, icon: const Icon(Icons.close_rounded, color: Colors.white)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(40, 12, 40, 0),
                child: DashedRRect(
                  child: const Padding(padding: EdgeInsets.all(20), child: DimFigure()),
                ),
              ),
            ),
            Container(
              margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 26,
                        height: 26,
                        decoration: const BoxDecoration(color: AppColors.warningYellow, shape: BoxShape.circle),
                        child: const Icon(Icons.priority_high_rounded, size: 16, color: Colors.white),
                      ),
                      const SizedBox(width: 10),
                      const Text('몸 전체가 보이지 않아요',
                          style: TextStyle(fontSize: 13.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                    ],
                  ),
                  const SizedBox(height: 10),
                  const Text('· 휴대폰을 조금 더 멀리 두세요\n· 머리부터 발끝까지 노란 틀 안에 들어오게\n· 밝은 곳에서 찍어 주세요',
                      style: TextStyle(fontSize: 11, color: AppColors.textDark, height: 1.7)),
                  const SizedBox(height: 8),
                  const Text('자동으로 다시 인식하고 있어요...',
                      style: TextStyle(fontSize: 10.5, color: AppColors.primary, fontWeight: FontWeight.w700)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: GestureDetector(
                onTap: _retry,
                child: Container(
                  height: 50,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
                  child: const Text('다시 인식하기',
                      style: TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
