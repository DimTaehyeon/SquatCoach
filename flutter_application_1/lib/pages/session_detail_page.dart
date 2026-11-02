import 'package:flutter/material.dart';

import '../config/squat_criteria.dart' show SquatFault;
import '../db/app_database.dart';
import '../models/workout_session.dart';
import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import '../widgets/common.dart';

/// 세션 기록 상세 (기록 목록에서 누르면 열림) / 운동 직후 결과 화면
///
/// 정확도·횟수·시간·칼로리, 세트별 결과, 자세 피드백
class SessionDetailPage extends StatefulWidget {
  const SessionDetailPage({super.key, required this.sessionId, this.isResult = false});

  final int sessionId;

  /// true면 운동 직후 결과 화면 (제목·버튼이 다름)
  final bool isResult;

  @override
  State<SessionDetailPage> createState() => _SessionDetailPageState();
}

class _SessionDetailPageState extends State<SessionDetailPage> {
  WorkoutSession? _session;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final s = await AppDatabase.instance.getSessionDetail(widget.sessionId);
    if (!mounted) return;
    setState(() {
      _session = s;
      _loading = false;
    });
  }

  Future<void> _delete() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('이 기록을 삭제할까요?'),
        content: const Text('세트별 결과도 함께 삭제되고 되돌릴 수 없어요.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('삭제')),
        ],
      ),
    );
    if (ok != true) return;
    await AppDatabase.instance.deleteSession(widget.sessionId);
    if (mounted) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final s = _session;
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        automaticallyImplyLeading: !widget.isResult,
        title: Text(widget.isResult ? '운동 결과' : '운동 기록',
            style: const TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (!widget.isResult && s != null)
            IconButton(
              tooltip: '기록 삭제',
              onPressed: _delete,
              icon: const Icon(Icons.delete_outline),
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : s == null
              ? const Center(child: Text('기록을 찾을 수 없어요'))
              : _content(s),
      bottomNavigationBar: widget.isResult
          ? SafeArea(
              minimum: const EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: FilledButton(
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(52)),
                onPressed: () => Navigator.pop(context, true),
                child: const Text('확인', style: TextStyle(fontSize: 16)),
              ),
            )
          : null,
    );
  }

  Widget _content(WorkoutSession s) {
    final end = s.startedAt.add(Duration(seconds: s.durationSec));
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 32),
      children: [
        if (widget.isResult)
          const Padding(
            padding: EdgeInsets.only(bottom: 12),
            child: Row(
              children: [
                Icon(Icons.check_circle, color: AppColors.good),
                SizedBox(width: 8),
                Text('운동 결과를 저장했어요',
                    style: TextStyle(fontSize: 15, color: AppColors.textPrimary)),
              ],
            ),
          ),
        Text(
          '${formatDateKo(s.startedAt)}  ${formatTime(s.startedAt)} – ${formatTime(end)}',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        const SizedBox(height: 10),

        // ---------- 요약 ----------
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            StatTile(
                label: '정확도',
                value: s.accuracy.toStringAsFixed(0),
                unit: '%',
                icon: Icons.track_changes),
            StatTile(
                label: '총 횟수',
                value: '${s.totalReps}',
                unit: '회 · ${s.setCount}세트',
                icon: Icons.fitness_center),
            StatTile(
                label: '운동 시간',
                value: formatDuration(s.durationSec),
                icon: Icons.timer_outlined),
            StatTile(
                label: '소모 칼로리',
                value: formatKcal(s.caloriesKcal),
                unit: 'kcal',
                icon: Icons.local_fire_department_outlined),
          ],
        ),

        // ---------- 자세 피드백 ----------
        const SectionTitle('자세 피드백'),
        _FeedbackCard(session: s),

        // ---------- 세트별 결과 ----------
        const SectionTitle('세트별 결과'),
        for (final set in s.sets) ...[
          _SetCard(set: set),
          const SizedBox(height: 10),
        ],
      ],
    );
  }
}

/// 세션 전체의 오류·참고 항목 집계
class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.session});
  final WorkoutSession session;

  @override
  Widget build(BuildContext context) {
    final faults = <String, int>{};
    final warnings = <String, int>{};
    for (final set in session.sets) {
      for (final r in set.reps) {
        for (final f in r.faults) {
          faults[f] = (faults[f] ?? 0) + 1;
        }
        for (final w in r.warnings) {
          warnings[w] = (warnings[w] ?? 0) + 1;
        }
      }
    }
    final aiLabels = <String, int>{};
    for (final set in session.sets) {
      for (final r in set.reps) {
        if (r.aiLabel != null) aiLabels[r.aiLabel!] = (aiLabels[r.aiLabel!] ?? 0) + 1;
      }
    }

    List<MapEntry<String, int>> sorted(Map<String, int> m) =>
        m.entries.toList()..sort((a, b) => b.value.compareTo(a.value));

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (faults.isEmpty)
            const _FeedbackRow(
              icon: Icons.check_circle,
              color: AppColors.good,
              title: '판정 오류 없음',
              detail: '모든 반복이 판정 기준을 통과했어요',
            )
          else
            for (final e in sorted(faults))
              _FeedbackRow(
                icon: Icons.error,
                color: AppColors.serious,
                title: '${e.key} ${e.value}회',
                detail: feedbackFor(e.key),
              ),
          if (warnings.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.cardBorder),
            const Text('참고 · 주의',
                style: TextStyle(fontSize: 12, color: AppColors.textMuted)),
            const SizedBox(height: 6),
            for (final e in sorted(warnings))
              _FeedbackRow(
                icon: Icons.remove_circle,
                color: AppColors.warning,
                title: '${e.key} ${e.value}회',
                detail: feedbackFor(e.key),
              ),
          ],
          if (aiLabels.isNotEmpty) ...[
            const Divider(height: 20, color: AppColors.cardBorder),
            Text(
              'AI 참고 판정: ${sorted(aiLabels).map((e) => '${e.key} ${e.value}회').join(' · ')}',
              style: const TextStyle(fontSize: 12, color: AppColors.textMuted),
            ),
          ],
        ],
      ),
    );
  }
}

class _FeedbackRow extends StatelessWidget {
  const _FeedbackRow({
    required this.icon,
    required this.color,
    required this.title,
    required this.detail,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String? detail;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    style: const TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w700,
                      color: AppColors.textPrimary,
                    )),
                if (detail != null)
                  Text(detail!,
                      style: const TextStyle(
                          fontSize: 12.5, color: AppColors.textSecondary)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SetCard extends StatelessWidget {
  const _SetCard({required this.set});
  final WorkoutSet set;

  @override
  Widget build(BuildContext context) {
    final ratio = set.totalReps == 0 ? 0.0 : set.goodReps / set.totalReps;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('세트 ${set.setIndex}',
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  )),
              const SizedBox(width: 8),
              Text('${formatTime(set.startedAt)} · ${formatDuration(set.durationSec)}',
                  style: const TextStyle(fontSize: 12.5, color: AppColors.textMuted)),
              const Spacer(),
              GradeBadge(score: set.averageScore),
            ],
          ),
          const SizedBox(height: 12),
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
                  text: ' / ${set.totalReps}회 정자세',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
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
          if (set.reps.isNotEmpty) ...[
            const SizedBox(height: 12),
            // 반복별 결과 (✓ 정자세 / ✕ 오류)
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: [
                for (final r in set.reps)
                  Tooltip(
                    message: r.isGood
                        ? '${r.repIndex}회차 정자세'
                        : '${r.repIndex}회차 ${r.faults.join(', ')}',
                    child: Container(
                      width: 30,
                      height: 30,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(
                            color: r.isGood
                                ? AppColors.good.withAlpha(150)
                                : AppColors.serious.withAlpha(150)),
                      ),
                      child: Icon(r.isGood ? Icons.check : Icons.close,
                          size: 16, color: r.isGood ? AppColors.good : AppColors.serious),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(set.feedback,
              style: const TextStyle(fontSize: 12.5, color: AppColors.textSecondary)),
        ],
      ),
    );
  }
}

/// 오류 이름 → 피드백 문구 (판정 기준 파일의 문구 사용)
String? feedbackFor(String label) {
  for (final f in SquatFault.values) {
    if (f.label == label) return f.feedback;
  }
  return null;
}
