import 'package:flutter/material.dart';

import '../../utils/camera_permission.dart';
import 'package:provider/provider.dart';

import '../../../config/squat_criteria.dart' show JudgeMode;
import '../../providers/session_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../widgets/primary_button.dart';

/// 운동 설정 (Figma: 셋트) — 스쿼트 종류, 세트 수, 세트당 횟수, 세트 사이 휴식
class WorkoutSetupTab extends StatelessWidget {
  const WorkoutSetupTab({super.key, required this.onBack});

  final VoidCallback onBack;

  static const _types = ['맨몸', '와이드', '점프'];
  static const _rests = [30, 60, 90];

  @override
  Widget build(BuildContext context) {
    final s = context.watch<SessionProvider>();
    final p = context.read<SessionProvider>();

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ScreenHeader(title: '운동 설정', onBack: onBack),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
            children: [
              _label('스쿼트 종류'),
              Row(
                children: [
                  for (final t in _types) ...[
                    Expanded(child: _chip(t, s.squatType == t, () => p.updateSetup(squatType: t))),
                    if (t != _types.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              _label('세트와 횟수'),
              _stepperCard('세트 수', '${s.totalSets}세트', () => p.updateSetup(sets: s.totalSets - 1),
                  () => p.updateSetup(sets: s.totalSets + 1)),
              const SizedBox(height: 10),
              _stepperCard('세트당 횟수', '${s.targetRepsPerSet}회', () => p.updateSetup(reps: s.targetRepsPerSet - 1),
                  () => p.updateSetup(reps: s.targetRepsPerSet + 1)),
              const SizedBox(height: 22),
              _label('세트 사이 휴식'),
              Row(
                children: [
                  for (final r in _rests) ...[
                    Expanded(child: _chip('$r초', s.restSeconds == r, () => p.updateSetup(rest: r))),
                    if (r != _rests.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 22),
              _label('판정 모드'),
              Row(
                children: [
                  for (final m in JudgeMode.values) ...[
                    Expanded(child: _chip(m.label, s.judgeMode == m, () => p.setJudgeMode(m))),
                    if (m != JudgeMode.values.last) const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 8),
              Text(s.judgeMode.description, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              const SizedBox(height: 22),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(color: AppColors.ringTrack, borderRadius: BorderRadius.circular(16)),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('오늘의 목표', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
                    const SizedBox(height: 4),
                    Text('총 ${s.plannedTotalReps}회 · 약 ${s.estimatedMinutes}분',
                        style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
          child: PrimaryButton(
            label: '카메라 준비하기',
            onPressed: () async {
              if (await ensureCameraPermission(context) && context.mounted) {
                Navigator.of(context).pushNamed('/camera-setup');
              }
            },
          ),
        ),
      ],
    );
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Text(text, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
      );

  Widget _chip(String text, bool selected, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        height: 42,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: selected ? AppColors.primary : Colors.white,
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: selected ? AppColors.primary : AppColors.cardBorder),
        ),
        child: Text(text,
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w700,
              color: selected ? Colors.white : AppColors.textDark,
            )),
      ),
    );
  }

  Widget _stepperCard(String label, String value, VoidCallback onMinus, VoidCallback onPlus) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Row(
        children: [
          Expanded(child: Text(label, style: const TextStyle(fontSize: 12.5, color: AppColors.textDark))),
          _roundBtn(Icons.remove_rounded, AppColors.background, AppColors.textDark, onMinus),
          SizedBox(
            width: 64,
            child: Text(value,
                textAlign: TextAlign.center,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          ),
          _roundBtn(Icons.add_rounded, AppColors.primary, Colors.white, onPlus),
        ],
      ),
    );
  }

  Widget _roundBtn(IconData icon, Color bg, Color fg, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
        child: Icon(icon, size: 18, color: fg),
      ),
    );
  }
}
