import 'package:flutter/material.dart';

import '../models/workout_session.dart';
import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import 'common.dart';

/// 기록 목록의 세션 한 줄
class SessionTile extends StatelessWidget {
  const SessionTile({super.key, required this.session, required this.onTap, this.showDate = true});

  final WorkoutSession session;
  final VoidCallback onTap;
  final bool showDate;

  @override
  Widget build(BuildContext context) {
    final s = session;
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          Container(
            width: 52,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text(
                  showDate ? '${s.startedAt.day}' : formatTime(s.startedAt),
                  style: TextStyle(
                    fontSize: showDate ? 18 : 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                Text(
                  showDate ? '${s.startedAt.month}월 ${weekdayKo(s.startedAt)}' : '시작',
                  style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${s.totalReps}회 · ${s.setCount}세트',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '정확도 ${s.accuracy.toStringAsFixed(0)}% · '
                  '${formatDuration(s.durationSec)} · ${formatKcal(s.caloriesKcal)}kcal',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary),
                ),
                if (s.memo != null && s.memo!.isNotEmpty) ...[
                  const SizedBox(height: 2),
                  Text(
                    s.memo!,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
                  ),
                ],
              ],
            ),
          ),
          GradeBadge(score: s.averageScore, showScore: false),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
