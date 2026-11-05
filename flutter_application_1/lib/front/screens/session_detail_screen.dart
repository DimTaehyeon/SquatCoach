import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_session.dart';
import '../providers/workout_provider.dart';
import '../theme/app_theme.dart';
import '../utils/format.dart';
import '../widgets/common.dart';

/// 세션 기록 상세 (Figma: 세션 기록)
class SessionDetailScreen extends StatelessWidget {
  const SessionDetailScreen({super.key, required this.sessionId});

  final String sessionId;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: ScreenHeader(
                title: '세션 기록',
                onBack: () => Navigator.of(context).pop(),
                trailing: RoundIconButton(
                  icon: Icons.ios_share_rounded,
                  onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('공유는 곧 지원할게요'))),
                ),
              ),
            ),
            Expanded(
              child: FutureBuilder<WorkoutSession>(
                future: context.read<WorkoutProvider>().sessionById(sessionId),
                builder: (context, snapshot) {
                  if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());
                  return _body(snapshot.data!);
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _body(WorkoutSession s) {
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
      children: [
        Center(
          child: Text(longDateTimeKo(s.date),
              style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600, color: AppColors.textMuted)),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(vertical: 18, horizontal: 16),
          decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
          child: Row(
            children: [
              _heroStat('${s.accuracy.round()}%', '평균 정확도'),
              _heroStat('${s.totalReps}회', '총 횟수'),
              _heroStat(s.formattedDuration, '운동 시간'),
            ],
          ),
        ),
        const SizedBox(height: 20),
        const Text('세트별 기록', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
        const SizedBox(height: 10),
        for (final r in s.setRecords) Padding(padding: const EdgeInsets.only(bottom: 10), child: _setCard(r)),
        if (s.feedbackNotes.isNotEmpty) ...[
          const SizedBox(height: 10),
          const Text('주요 피드백', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 10),
          SoftCard(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in s.feedbackNotes)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 3),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('•  ', style: TextStyle(color: AppColors.textMuted)),
                        Expanded(child: Text(n, style: const TextStyle(fontSize: 11.5, color: AppColors.textDark))),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _heroStat(String value, String label) => Expanded(
        child: Column(
          children: [
            Text(value, style: const TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(label, style: const TextStyle(color: Colors.white70, fontSize: 10)),
          ],
        ),
      );

  Widget _setCard(SetRecord r) {
    final low = r.accuracy < 80;
    final color = low ? AppColors.amber : AppColors.primary;
    return SoftCard(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('${r.setNumber}세트',
                  style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const Spacer(),
              Text('${r.accuracy.round()}%', style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w800, color: color)),
            ],
          ),
          const SizedBox(height: 2),
          Text(
            '${r.reps}회 · ${r.formattedDuration}${r.note != null ? ' · ${r.note}' : ''}',
            style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted),
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: r.accuracy / 100),
              duration: const Duration(milliseconds: 600),
              curve: Curves.easeOutCubic,
              builder: (context, v, _) => LinearProgressIndicator(
                value: v,
                minHeight: 5,
                backgroundColor: AppColors.cardBorder,
                valueColor: AlwaysStoppedAnimation(color),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
