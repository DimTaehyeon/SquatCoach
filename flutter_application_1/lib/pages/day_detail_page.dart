import 'package:flutter/material.dart';

import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/session_tile.dart';
import 'session_detail_page.dart';

/// 특정 날짜에 한 운동 목록 (차트 막대를 누르면 열림)
class DayDetailPage extends StatelessWidget {
  const DayDetailPage({super.key, required this.day});

  final DaySummary day;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: Text(formatDateKo(day.date), style: const TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
        children: [
          AppCard(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
            child: Row(
              children: [
                _item('운동', '${day.sessionCount}회'),
                _item('총 횟수', '${day.totalReps}회'),
                _item('정확도', '${day.accuracy.toStringAsFixed(0)}%'),
                _item('칼로리', '${formatKcal(day.caloriesKcal)}kcal'),
              ],
            ),
          ),
          const SectionTitle('운동 기록'),
          for (final s in day.sessions) ...[
            SessionTile(
              session: s,
              showDate: false,
              onTap: () async {
                final changed = await Navigator.push<bool>(
                  context,
                  MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id!)),
                );
                // 삭제했으면 목록이 바뀌었으니 닫기 (홈이 새로 불러옴)
                if (changed == true && context.mounted) Navigator.pop(context);
              },
            ),
            const SizedBox(height: 8),
          ],
        ],
      ),
    );
  }

  Widget _item(String label, String value) => Expanded(
        child: Column(
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(value,
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
            ),
            const SizedBox(height: 4),
            Text(label, style: const TextStyle(fontSize: 11.5, color: AppColors.textMuted)),
          ],
        ),
      );
}
