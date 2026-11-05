import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/session_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/figure_painter.dart';
import '../widgets/primary_button.dart';

/// 일시정지 화면이 돌려주는 선택 결과 (분석 화면이 받아서 처리)
enum PauseAction { resume, restartSet, end, exitHome }

/// 일시정지 (Figma: 정지) — 어두운 배경 위에 아래에서 올라온 시트 모양.
class PausedScreen extends StatelessWidget {
  const PausedScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionProvider>();

    return PopScope(
      canPop: true,
      child: Scaffold(
        backgroundColor: AppColors.pageDark,
        body: Stack(
          children: [
            const Positioned.fill(
              child: Padding(
                padding: EdgeInsets.fromLTRB(90, 140, 90, 360),
                child: Opacity(opacity: 0.5, child: DimFigure(color: Color(0xFF3A4540))),
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.fromLTRB(20, 10, 20, 24),
                decoration: const BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(color: AppColors.cardBorder, borderRadius: BorderRadius.circular(2)),
                      ),
                      const SizedBox(height: 16),
                      const Text('일시정지', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                      const SizedBox(height: 14),
                      Container(
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        decoration: BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.circular(16)),
                        child: Row(
                          children: [
                            _stat('${s.currentSet}세트', '진행 중'),
                            _divider(),
                            _stat('${s.repsInSet} / ${s.targetRepsPerSet}회', '횟수'),
                            _divider(),
                            _stat(mmss(s.elapsedSeconds), '운동 시간'),
                          ],
                        ),
                      ),
                      const SizedBox(height: 16),
                      PrimaryButton(label: '계속하기', onPressed: () => Navigator.of(context).pop(PauseAction.resume)),
                      const SizedBox(height: 10),
                      PrimaryButton(
                        label: '이번 세트 다시 하기',
                        filled: false,
                        onPressed: () => Navigator.of(context).pop(PauseAction.restartSet),
                      ),
                      const SizedBox(height: 4),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(PauseAction.end),
                        child: const Text('운동 끝내기',
                            style: TextStyle(color: AppColors.danger, fontSize: 13, fontWeight: FontWeight.w700)),
                      ),
                      TextButton(
                        onPressed: () => Navigator.of(context).pop(PauseAction.exitHome),
                        child: const Text('저장 없이 홈으로 나가기',
                            style: TextStyle(color: AppColors.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
          ],
        ),
      );

  Widget _divider() => Container(width: 1, height: 28, color: AppColors.cardBorder);
}
