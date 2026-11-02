import 'package:flutter/material.dart';

import '../config/squat_criteria.dart' show SquatFault, CheckRole;
import '../ui/app_colors.dart';
import '../widgets/common.dart';
import 'ai_coach_page.dart';

/// 운동 탭: 촬영 안내 + 판정 항목 + 시작 버튼
class WorkoutStartPage extends StatelessWidget {
  const WorkoutStartPage({super.key});

  @override
  Widget build(BuildContext context) {
    final judged = SquatFault.values.where((f) => f.role == CheckRole.judged);
    final refs = SquatFault.values.where((f) => f.role == CheckRole.reference);

    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('스쿼트', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          const AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('촬영 준비',
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    )),
                SizedBox(height: 10),
                _Step(n: 1, text: '폰을 허리 높이에 세워 두세요'),
                _Step(n: 2, text: '2~3m 떨어져서 카메라 정면에 서세요'),
                _Step(n: 3, text: '머리부터 발끝까지 화면에 들어오는지 확인하세요'),
                _Step(n: 4, text: '세트마다 처음 2초는 똑바로 서서 영점을 잡아요'),
              ],
            ),
          ),
          const SectionTitle('이렇게 판정해요'),
          AppCard(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('하나라도 해당되면 그 1회는 오류',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                for (final f in judged)
                  _FaultRow(icon: Icons.error, color: AppColors.serious, fault: f),
                const Divider(height: 22, color: AppColors.cardBorder),
                const Text('참고로 알려 드려요',
                    style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
                const SizedBox(height: 6),
                for (final f in refs)
                  _FaultRow(icon: Icons.remove_circle, color: AppColors.warning, fault: f),
              ],
            ),
          ),
          const SizedBox(height: 20),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(54)),
            onPressed: () => Navigator.push(
                context, MaterialPageRoute(builder: (_) => const WorkoutPage())),
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('운동 시작', style: TextStyle(fontSize: 17, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 10),
          const Text(
            '영상은 저장하거나 전송하지 않고, 폰 안에서만 실시간으로 분석해요',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.n, required this.text});
  final int n;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          CircleAvatar(
            radius: 11,
            backgroundColor: AppColors.seriesSoft,
            child: Text('$n',
                style: const TextStyle(fontSize: 12, color: AppColors.textPrimary)),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text,
                style: const TextStyle(fontSize: 14, color: AppColors.textSecondary)),
          ),
        ],
      ),
    );
  }
}

class _FaultRow extends StatelessWidget {
  const _FaultRow({required this.icon, required this.color, required this.fault});
  final IconData icon;
  final Color color;
  final SquatFault fault;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 17, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(fault.label,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                Text(fault.feedback,
                    style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
