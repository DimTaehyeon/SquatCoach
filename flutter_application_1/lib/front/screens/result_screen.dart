import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../providers/session_provider.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';
import '../widgets/primary_button.dart';

/// 운동 결과 (Figma: 결과)
class ResultScreen extends StatelessWidget {
  const ResultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // 이 화면에서는 값이 바뀌지 않으므로 read로 한 번만 읽습니다.
    final s = context.read<SessionProvider>();
    final name = context.read<ProfileProvider>().user.name;
    final displayName = name.isEmpty ? '회원' : name;
    final accuracy = s.overallAccuracy;
    final feedback = s.buildFeedbackItems();

    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 24, 20, 12),
                children: [
                  const Center(child: Text('운동 완료', style: TextStyle(fontSize: 11, color: AppColors.textMuted))),
                  const SizedBox(height: 4),
                  Center(
                    child: Text('수고하셨어요, $displayName님!',
                        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ),
                  const SizedBox(height: 18),
                  Center(
                    child: SizedBox(
                      width: 150,
                      height: 150,
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: accuracy / 100),
                            duration: const Duration(milliseconds: 900),
                            curve: Curves.easeOutCubic,
                            builder: (context, v, _) => SizedBox(
                              width: 150,
                              height: 150,
                              child: CircularProgressIndicator(
                                value: v,
                                strokeWidth: 11,
                                strokeCap: StrokeCap.round,
                                backgroundColor: const Color(0xFFE6E0CE),
                                valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                              ),
                            ),
                          ),
                          Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              RichText(
                                text: TextSpan(
                                  style: const TextStyle(color: AppColors.textDark, fontWeight: FontWeight.w800),
                                  children: [
                                    TextSpan(text: '$accuracy', style: const TextStyle(fontSize: 34)),
                                    const TextSpan(text: '%', style: TextStyle(fontSize: 16)),
                                  ],
                                ),
                              ),
                              const Text('평균 정확도', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(child: StatTile(value: '${s.totalReps}', unit: '회', label: '총 반복 횟수')),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: '${s.setRecords.length}', unit: '세트', label: '완료 세트')),
                      const SizedBox(width: 8),
                      Expanded(child: StatTile(value: mmss(s.elapsedSeconds), label: '운동 시간')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  const Text('자세교정 피드백', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const SizedBox(height: 10),
                  for (final f in feedback) Padding(padding: const EdgeInsets.only(bottom: 10), child: _feedbackCard(f)),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
              child: PrimaryButton(
                label: '기록 저장하고 완료',
                onPressed: () async {
                  final workout = context.read<WorkoutProvider>();
                  s.reset(); // 기록은 운동이 끝날 때 이미 저장됨
                  await workout.refresh();
                  if (context.mounted) {
                    Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
                  }
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _feedbackCard(FeedbackItem f) {
    final Color tileBg;
    final Color tileFg;
    final IconData icon;
    Color cardBg = Colors.white;
    switch (f.level) {
      case FeedbackLevel.warning:
        tileBg = AppColors.warningBg;
        tileFg = AppColors.warningYellow;
        icon = Icons.warning_amber_rounded;
      case FeedbackLevel.danger:
        tileBg = AppColors.dangerSoft;
        tileFg = AppColors.danger;
        icon = Icons.warning_amber_rounded;
      case FeedbackLevel.good:
        tileBg = AppColors.primary;
        tileFg = Colors.white;
        icon = Icons.check_rounded;
        cardBg = AppColors.primarySoft;
    }
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(color: tileBg, borderRadius: BorderRadius.circular(10)),
            child: Icon(icon, size: 18, color: tileFg),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(f.title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const SizedBox(height: 3),
                Text(f.description, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.45)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
