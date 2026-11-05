import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/user_profile.dart';
import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';
import '../widgets/primary_button.dart';

/// 운동 목표 선택 (Figma: 목표선택)
class GoalScreen extends StatefulWidget {
  const GoalScreen({super.key});

  @override
  State<GoalScreen> createState() => _GoalScreenState();
}

class _GoalScreenState extends State<GoalScreen> {
  late FitnessGoal _goal = context.read<ProfileProvider>().user.goal ?? FitnessGoal.postureCorrection;

  static const _icons = {
    FitnessGoal.postureCorrection: Icons.stacked_bar_chart_rounded,
    FitnessGoal.strength: Icons.fitness_center_rounded,
    FitnessGoal.rehab: Icons.history_rounded,
  };

  Future<void> _next() async {
    await context.read<ProfileProvider>().setGoal(_goal);
    if (mounted) Navigator.of(context).pushReplacementNamed('/permission');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 36, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('운동 목표를 알려주세요',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textDark)),
              const SizedBox(height: 4),
              const Text('목표에 맞춰 코칭 강도를 조정해드려요', style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
              const SizedBox(height: 22),
              ...FitnessGoal.values.map(_goalCard),
              const SizedBox(height: 10),
              SoftCard(
                child: Row(
                  children: [
                    const IconTile(icon: Icons.photo_camera_outlined, size: 36),
                    const SizedBox(width: 12),
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('카메라 접근 권한이 필요해요',
                              style: TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                          SizedBox(height: 2),
                          Text('실시간 자세 분석을 위해 운동 중에만 카메라를 사용해요. 촬영된 영상은 저장되지 않아요.',
                              style: TextStyle(fontSize: 10.5, color: AppColors.textMuted, height: 1.4)),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(label: '시작하기', onPressed: _next),
            ],
          ),
        ),
      ),
    );
  }

  Widget _goalCard(FitnessGoal goal) {
    final selected = goal == _goal;
    return GestureDetector(
      onTap: () => setState(() => _goal = goal),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: selected ? AppColors.primarySoft : Colors.white,
          borderRadius: BorderRadius.circular(AppRadius.card),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder, width: selected ? 1.4 : 1),
        ),
        child: Row(
          children: [
            IconTile(
              icon: _icons[goal]!,
              size: 36,
              background: selected ? AppColors.primary : AppColors.background,
              iconColor: selected ? Colors.white : AppColors.textMuted,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(goal.title,
                      style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                  const SizedBox(height: 2),
                  Text(goal.subtitle, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                ],
              ),
            ),
            if (selected)
              Container(
                width: 22,
                height: 22,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: const Icon(Icons.check_rounded, size: 14, color: Colors.white),
              ),
          ],
        ),
      ),
    );
  }
}
