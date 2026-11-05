import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/workout_session.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// 운동 기록 (Figma: 기록)
class RecordsTab extends StatelessWidget {
  const RecordsTab({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();
    final summary = workout.summary;
    final sessions = workout.sessions;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ScreenHeader(
            title: '운동 기록',
            onBack: onBack,
            trailing: RoundIconButton(
              icon: Icons.tune_rounded,
              onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('필터는 곧 지원할게요'))),
            ),
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            children: [
              SoftCard(
                radius: 20,
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('이번 주 정확도 평균', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        RichText(
                          text: TextSpan(
                            style: const TextStyle(color: AppColors.primary, fontWeight: FontWeight.w800),
                            children: [
                              TextSpan(text: summary.weeklyAccuracy.toStringAsFixed(1), style: const TextStyle(fontSize: 28)),
                              const TextSpan(text: '%', style: TextStyle(fontSize: 14)),
                            ],
                          ),
                        ),
                        const Spacer(),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                          decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(summary.weeklyAccuracyDelta >= 0 ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                                  size: 14, color: AppColors.primary),
                              Text('${summary.weeklyAccuracyDelta.abs()}%',
                                  style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.primary)),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    SizedBox(height: 110, child: _WeekBars(data: workout.weeklyAccuracy)),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(child: StatTile(value: '${summary.totalReps}', label: '총 스쿼트 횟수')),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: '${summary.bestStreakDays}일', label: '최장 연속 기록')),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: '${summary.totalCalories}kcal', label: '총 누적 칼로리')),
                ],
              ),
              const SizedBox(height: 10),
              SoftCard(
                onTap: () => Navigator.of(context).pushNamed('/calories'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                child: Row(
                  children: [
                    const IconTile(icon: Icons.local_fire_department_rounded, size: 34, background: AppColors.warningBg, iconColor: AppColors.amber),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Text('칼로리 활동 보기',
                          style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                    ),
                    const Icon(Icons.chevron_right_rounded, color: AppColors.textMuted),
                  ],
                ),
              ),
              const SizedBox(height: 20),
              Row(
                children: [
                  const Text('세션 기록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  const Spacer(),
                  const Text('전체 보기', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ],
              ),
              const SizedBox(height: 10),
              if (workout.isLoading && sessions.isEmpty)
                const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator()))
              else if (sessions.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('아직 운동 기록이 없어요', style: TextStyle(color: AppColors.textMuted))),
                )
              else
                for (var i = 0; i < sessions.length; i++)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 10),
                    child: _SessionRow(
                      session: sessions[i],
                      highlighted: i == 0,
                      onTap: () => Navigator.of(context).pushNamed('/session-detail', arguments: sessions[i].id),
                    ),
                  ),
            ],
          ),
        ),
      ],
    );
  }
}

class _WeekBars extends StatelessWidget {
  const _WeekBars({required this.data});
  final List<DailyStat> data;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) return const SizedBox.shrink();
    final maxV = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    const baseline = 40.0;
    final span = (maxV - baseline) <= 0 ? 1.0 : (maxV - baseline);
    final todayIndex = DateTime.now().weekday - 1; // 월=0 ... 일=6
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        for (var i = 0; i < data.length; i++)
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Expanded(
                    child: TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: (data[i].value <= 0 ? 0.08 : ((data[i].value - baseline) / span).clamp(0.08, 1.0)).toDouble()),
                      duration: Duration(milliseconds: 500 + i * 60),
                      curve: Curves.easeOutCubic,
                      builder: (context, v, _) => FractionallySizedBox(
                        heightFactor: v,
                        alignment: Alignment.bottomCenter,
                        child: Container(
                          decoration: BoxDecoration(
                            color: i == todayIndex ? AppColors.primary : AppColors.barLight,
                            borderRadius: BorderRadius.circular(6),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(data[i].label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: i == todayIndex ? FontWeight.w800 : FontWeight.w500,
                        color: i == todayIndex ? AppColors.textDark : AppColors.textMuted,
                      )),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

class _SessionRow extends StatelessWidget {
  const _SessionRow({required this.session, required this.highlighted, required this.onTap});
  final WorkoutSession session;
  final bool highlighted;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SoftCard(
      onTap: onTap,
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconTile(
            icon: Icons.accessibility_new_rounded,
            size: 38,
            background: highlighted ? AppColors.ringTrack : AppColors.background,
            iconColor: highlighted ? AppColors.primary : AppColors.textMuted,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dayLabelKo(session.date)} · ${timeOfDayKo(session.date)}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('${session.totalSets}세트 · ${session.totalReps}회',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Text('${session.accuracy.round()}%',
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w800,
                color: highlighted ? AppColors.primary : AppColors.textDark,
              )),
        ],
      ),
    );
  }
}
