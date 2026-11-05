import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/workout_session.dart';
import '../../providers/profile_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/profile_avatar.dart';
import '../../utils/format.dart';
import '../../widgets/bottom_nav_bar.dart';
import '../../widgets/common.dart';

/// 홈 (Figma: 메인)
class MainTab extends StatelessWidget {
  const MainTab({super.key, required this.onGoTab});

  final ValueChanged<AppTab> onGoTab;

  String _greeting() {
    final h = DateTime.now().hour;
    if (h < 12) return '좋은 아침이에요';
    if (h < 18) return '좋은 오후예요';
    return '좋은 저녁이에요';
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<ProfileProvider>().user;
    final workout = context.watch<WorkoutProvider>();
    final summary = workout.summary;
    final latest = workout.latestSession;
    final name = user.name.isEmpty ? '회원' : user.name;

    return RefreshIndicator(
      onRefresh: workout.refresh,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 14, 20, 24),
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('SQUAT COACH',
                        style: TextStyle(fontSize: 9.5, letterSpacing: 1.4, fontWeight: FontWeight.w800, color: AppColors.primaryLight)),
                    const SizedBox(height: 4),
                    Text('$name님, ${_greeting()}',
                        style: const TextStyle(fontSize: 19, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
              ),
              RoundIconButton(
                icon: Icons.notifications_none_rounded,
                onTap: () => ScaffoldMessenger.of(context)
                    .showSnackBar(const SnackBar(content: Text('새 알림이 없어요'))),
              ),
              const SizedBox(width: 8),
              GestureDetector(
                onTap: () => onGoTab(AppTab.my),
                child: ProfileAvatar(user: user, size: 40, radius: 12, fontSize: 15, color: AppColors.primary),
              ),
            ],
          ),
          const SizedBox(height: 18),
          _weeklyCard(summary),
          const SizedBox(height: 22),
          const Text('바로가기', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 10),
          GestureDetector(
            onTap: () => onGoTab(AppTab.workout),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppColors.primary, AppColors.primaryLight]),
                borderRadius: BorderRadius.circular(AppRadius.cardLarge),
              ),
              child: Row(
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                    child: const Icon(Icons.accessibility_new_rounded, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('운동 하기', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('AI가 실시간으로 스쿼트 자세를 분석해요',
                            style: TextStyle(color: Colors.white70, fontSize: 10.5)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: Colors.white),
                ],
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _shortcut(Icons.bar_chart_rounded, '운동 기록', '통계 & 히스토리', () => onGoTab(AppTab.records)),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _shortcut(Icons.person_outline_rounded, '마이페이지', '프로필 & 설정', () => onGoTab(AppTab.my)),
              ),
            ],
          ),
          const SizedBox(height: 22),
          const Text('최근 운동', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 10),
          if (latest == null)
            const Text('아직 운동 기록이 없어요', style: TextStyle(color: AppColors.textMuted, fontSize: 12))
          else
            _recentRow(context, latest),
        ],
      ),
    );
  }

  Widget _weeklyCard(ActivitySummary s) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(22)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text('이번 주 스쿼트', style: TextStyle(color: Colors.white70, fontSize: 11)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(12)),
                child: Text('${s.streakDays}일 연속',
                    style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w700)),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    RichText(
                      text: TextSpan(
                        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                        children: [
                          TextSpan(text: '${s.weeklyReps}', style: const TextStyle(fontSize: 34)),
                          const TextSpan(text: '회', style: TextStyle(fontSize: 14)),
                        ],
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                        s.totalSessions == 0
                            ? '첫 운동을 시작해 보세요'
                            : '지난주보다 ${s.weeklyRepsDelta.abs()}회 ${s.weeklyRepsDelta >= 0 ? '증가' : '감소'}',
                        style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                  ],
                ),
              ),
              SizedBox(
                width: 120,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text('평균 정확도', style: TextStyle(color: Colors.white70, fontSize: 10)),
                        Text('${s.weeklyAccuracy.round()}%',
                            style: const TextStyle(color: Colors.white, fontSize: 10.5, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(4),
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(begin: 0, end: s.weeklyAccuracy / 100),
                        duration: const Duration(milliseconds: 700),
                        builder: (context, v, _) => LinearProgressIndicator(
                          value: v,
                          minHeight: 6,
                          backgroundColor: Colors.white24,
                          valueColor: const AlwaysStoppedAnimation(AppColors.accentMint),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _shortcut(IconData icon, String title, String sub, VoidCallback onTap) {
    return SoftCard(
      onTap: onTap,
      radius: 18,
      padding: const EdgeInsets.all(14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconTile(icon: icon, size: 34),
          const SizedBox(height: 10),
          Text(title, style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 2),
          Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
        ],
      ),
    );
  }

  Widget _recentRow(BuildContext context, WorkoutSession s) {
    return SoftCard(
      onTap: () => Navigator.of(context).pushNamed('/session-detail', arguments: s.id),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          IconTile(icon: Icons.schedule_rounded, size: 38, background: AppColors.background, iconColor: AppColors.textMuted),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('${dayLabelKo(s.date)} ${timeOfDayKo(s.date)}',
                    style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text('스쿼트 ${s.totalSets}세트 · 정확도 ${s.accuracy.round()}%',
                    style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(10)),
            child: const Text('완료', style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
          ),
        ],
      ),
    );
  }
}
