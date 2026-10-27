import 'package:flutter/material.dart';

import '../models/workout_session.dart';
import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import '../widgets/common.dart';

/// 특정 날짜의 세트별 세부 결과
class DayDetailPage extends StatelessWidget {
  const DayDetailPage({super.key, required this.day, required this.userName});

  final DaySummary day;
  final String userName;

  @override
  Widget build(BuildContext context) {
    final bestScore = day.sets
        .map((s) => s.averageScore)
        .fold<double>(0, (a, b) => a > b ? a : b);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(formatDateKo(day.date),
                style: const TextStyle(fontWeight: FontWeight.w700)),
            Text('$userName님의 운동 기록',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondary)),
          ],
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
        children: [
          // ---------- 하루 요약 ----------
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                _SummaryItem(label: '세트', value: '${day.setCount}'),
                _divider(),
                _SummaryItem(label: '총 횟수', value: '${day.totalReps}회'),
                _divider(),
                _SummaryItem(
                    label: '평균 점수',
                    value: day.averageScore.toStringAsFixed(1)),
                _divider(),
                _SummaryItem(
                    label: '운동 시간', value: formatDuration(day.totalSec)),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              const Text('하루 평가',
                  style:
                      TextStyle(fontSize: 13, color: AppColors.textSecondary)),
              const SizedBox(width: 8),
              GradeBadge(score: day.averageScore, showScore: false),
              const Spacer(),
              Text('정확도 ${day.accuracy.toStringAsFixed(0)}%',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary)),
            ],
          ),

          // ---------- 세트별 결과 ----------
          const SectionTitle('세트별 결과'),
          for (var i = 0; i < day.sets.length; i++) ...[
            _SetCard(
              index: i + 1,
              set: day.sets[i],
              isBest: day.sets.length > 1 &&
                  day.sets[i].averageScore == bestScore,
            ),
            const SizedBox(height: 10),
          ],
        ],
      ),
    );
  }

  Widget _divider() =>
      Container(width: 1, height: 32, color: AppColors.cardBorder);
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Column(
        children: [
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(value,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                )),
          ),
          const SizedBox(height: 4),
          Text(label,
              style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({required this.index, required this.set, required this.isBest});

  final int index;
  final WorkoutSession set;
  final bool isBest;

  @override
  Widget build(BuildContext context) {
    final ratio = set.totalReps == 0 ? 0.0 : set.goodReps / set.totalReps;
    final badReps = set.totalReps - set.goodReps;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 제목 줄
          Row(
            children: [
              Text('세트 $index',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(width: 8),
              Text(formatTime(set.startedAt),
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textMuted)),
              if (isBest) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: AppColors.seriesSoft,
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: const Text('최고 기록',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      )),
                ),
              ],
              const Spacer(),
              GradeBadge(score: set.averageScore),
            ],
          ),
          const SizedBox(height: 14),

          // 정확한 횟수 비율 막대
          Row(
            children: [
              Text.rich(TextSpan(children: [
                TextSpan(
                  text: '${set.goodReps}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextSpan(
                  text: ' / ${set.totalReps}회 정확',
                  style: const TextStyle(
                      fontSize: 13, color: AppColors.textSecondary),
                ),
              ])),
              const Spacer(),
              Text('${(ratio * 100).toStringAsFixed(0)}%',
                  style: const TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  )),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: ratio,
              minHeight: 8,
              color: AppColors.series,
              backgroundColor: AppColors.grid,
            ),
          ),
          const SizedBox(height: 12),

          // 세부 정보
          Wrap(
            spacing: 14,
            runSpacing: 6,
            children: [
              _Meta(Icons.timer_outlined, formatDuration(set.durationSec)),
              _Meta(Icons.close_rounded, '자세 흐트러짐 $badReps회'),
              if (set.memo != null && set.memo!.isNotEmpty)
                _Meta(Icons.notes_rounded, set.memo!),
            ],
          ),
        ],
      ),
    );
  }
}

class _Meta extends StatelessWidget {
  const _Meta(this.icon, this.text);
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 15, color: AppColors.textMuted),
        const SizedBox(width: 4),
        Text(text,
            style: const TextStyle(
                fontSize: 12.5, color: AppColors.textSecondary)),
      ],
    );
  }
}
