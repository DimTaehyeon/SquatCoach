import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/workout_session.dart';
import '../utils/calorie_series.dart';
import '../providers/workout_provider.dart';
import '../repositories/workout_repository.dart';
import '../theme/app_theme.dart';
import '../widgets/common.dart';

/// 칼로리 활동 — 일간/주간/월간 소모 칼로리 막대 그래프 + 목표 대비 남은 칼로리.
/// (참고 시안: Walk Activity 화면을 Squat Coach 색/카드 스타일에 맞춰 변환)
class CalorieActivityScreen extends StatefulWidget {
  const CalorieActivityScreen({super.key});

  @override
  State<CalorieActivityScreen> createState() => _CalorieActivityScreenState();
}

class _CalorieActivityScreenState extends State<CalorieActivityScreen> {
  /// 기간별 목표 칼로리. 나중에 프로필 설정으로 옮기면 됩니다.
  static const _goals = {
    CalorieRange.daily: 120,
    CalorieRange.weekly: 600,
    CalorieRange.monthly: 2400,
  };
  static const _rangeLabels = {
    CalorieRange.daily: '일간',
    CalorieRange.weekly: '주간',
    CalorieRange.monthly: '월간',
  };
  static const _titles = {
    CalorieRange.daily: '오늘 소모 칼로리',
    CalorieRange.weekly: '이번 주 소모 칼로리',
    CalorieRange.monthly: '이번 달 소모 칼로리',
  };

  CalorieRange _range = CalorieRange.weekly;
  int? _selected; // 탭한 막대 (없으면 가장 높은 막대)

  void _changeRange(CalorieRange r) {
    if (r == _range) return;
    setState(() {
      _range = r;
      _selected = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final workout = context.watch<WorkoutProvider>();
    final report = workout.calorieReport(_range);
    final data = report.bars;
    final goal = _goals[_range]!;
    final reps = report.totalReps;
    final burnt = report.totalKcal;
    final left = (goal - burnt).clamp(0, goal).toInt();
    final percent = goal == 0 ? 0 : ((burnt / goal) * 100).clamp(0, 100).round();
    final loading = workout.isLoading && workout.sessions.isEmpty;

    return Scaffold(
      body: SafeArea(
        child: Builder(
          builder: (context) {
            return Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
                  child: ScreenHeader(
                    title: '칼로리 활동',
                    onBack: () => Navigator.of(context).pop(),
                    trailing: RoundIconButton(
                      icon: Icons.ios_share_rounded,
                      onTap: () => ScaffoldMessenger.of(context)
                          .showSnackBar(const SnackBar(content: Text('공유 기능은 곧 지원할게요'))),
                    ),
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(20, 14, 20, 20),
                    children: [
                      _RangeTabs(selected: _range, labels: _rangeLabels, onChanged: _changeRange),
                      const SizedBox(height: 18),
                      Text(_titles[_range]!, style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                      const SizedBox(height: 2),
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          TweenAnimationBuilder<double>(
                            tween: Tween(begin: 0, end: burnt.toDouble()),
                            duration: const Duration(milliseconds: 700),
                            curve: Curves.easeOutCubic,
                            builder: (_, v, __) => Text(
                              '${v.round()}',
                              style: const TextStyle(fontSize: 44, fontWeight: FontWeight.w800, height: 1.1, color: AppColors.textDark),
                            ),
                          ),
                          const SizedBox(width: 6),
                          const Padding(
                            padding: EdgeInsets.only(bottom: 7),
                            child: Text('kcal', style: TextStyle(fontSize: 15, color: AppColors.textMuted)),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),
                      SoftCard(
                        radius: 20,
                        padding: const EdgeInsets.fromLTRB(10, 16, 14, 12),
                        child: AnimatedSwitcher(
                          duration: const Duration(milliseconds: 250),
                          child: loading
                              ? const SizedBox(key: ValueKey('loading'), height: 220, child: Center(child: CircularProgressIndicator()))
                              : _BarChart(
                                  key: ValueKey(_range),
                                  data: data,
                                  selected: _selected,
                                  onSelect: (i) => setState(() => _selected = i),
                                ),
                        ),
                      ),
                      const SizedBox(height: 12),
                      _TotalCard(reps: reps, percent: percent),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: _KcalCard(
                              label: '소모 칼로리',
                              value: burnt,
                              icon: Icons.local_fire_department_rounded,
                              background: AppColors.primarySoft,
                              iconColor: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 10),
                          Expanded(
                            child: _KcalCard(
                              label: '남은 칼로리',
                              value: left,
                              icon: Icons.local_fire_department_rounded,
                              background: AppColors.warningBg,
                              iconColor: AppColors.amber,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// 일간 / 주간 / 월간 알약 탭
class _RangeTabs extends StatelessWidget {
  const _RangeTabs({required this.selected, required this.labels, required this.onChanged});

  final CalorieRange selected;
  final Map<CalorieRange, String> labels;
  final ValueChanged<CalorieRange> onChanged;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        for (final r in CalorieRange.values) ...[
          Expanded(
            child: GestureDetector(
              onTap: () => onChanged(r),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 220),
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: r == selected ? AppColors.primary : Colors.white,
                  borderRadius: BorderRadius.circular(AppRadius.pill),
                  border: Border.all(color: r == selected ? AppColors.primary : AppColors.cardBorder),
                ),
                child: Text(
                  labels[r]!,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                    color: r == selected ? Colors.white : AppColors.textDark,
                  ),
                ),
              ),
            ),
          ),
          if (r != CalorieRange.values.last) const SizedBox(width: 8),
        ],
      ],
    );
  }
}

/// 세로 격자선 + y축 눈금 + 막대 그래프. 가장 높은 막대는 주황~빨강 강조.
class _BarChart extends StatelessWidget {
  const _BarChart({super.key, required this.data, required this.selected, required this.onSelect});

  final List<DailyStat> data;
  final int? selected;
  final ValueChanged<int> onSelect;

  static const _plotHeight = 180.0;

  @override
  Widget build(BuildContext context) {
    final maxV = data.map((d) => d.value).reduce((a, b) => a > b ? a : b);
    final step = const [10, 20, 25, 50, 100, 200, 500].firstWhere((s) => maxV / s <= 4, orElse: () => 1000);
    final top = (maxV / step).ceil().clamp(1, 100) * step;
    final peak = data.indexWhere((d) => d.value == maxV);
    final active = selected ?? peak;
    final ticks = [for (var v = top; v >= 0; v -= step) v];

    return Column(
      children: [
        SizedBox(
          height: _plotHeight,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                width: 34,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    for (final t in ticks)
                      Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: Text('$t', style: const TextStyle(fontSize: 9.5, color: AppColors.textFaint)),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    Positioned.fill(
                      child: Row(
                        children: [
                          for (var i = 0; i < data.length; i++)
                            Expanded(
                              child: Container(
                                decoration: BoxDecoration(
                                  border: Border(left: BorderSide(color: AppColors.cardBorder.withOpacity(0.6))),
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (var i = 0; i < data.length; i++)
                          Expanded(
                            child: GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () => onSelect(i),
                              child: _Bar(
                                value: data[i].value,
                                top: top.toDouble(),
                                isPeak: i == peak,
                                isActive: i == active,
                                delayMs: i * 60,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            const SizedBox(width: 34),
            for (var i = 0; i < data.length; i++)
              Expanded(
                child: Text(
                  data[i].label,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: i == active ? FontWeight.w800 : FontWeight.w500,
                    color: i == active ? AppColors.textDark : AppColors.textMuted,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

class _Bar extends StatelessWidget {
  const _Bar({required this.value, required this.top, required this.isPeak, required this.isActive, required this.delayMs});

  final double value;
  final double top;
  final bool isPeak;
  final bool isActive;
  final int delayMs;

  @override
  Widget build(BuildContext context) {
    final factor = value <= 0 ? 0.0 : (value / top).clamp(0.03, 1.0).toDouble();
    return Align(
      alignment: Alignment.bottomCenter,
      child: TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: factor),
        duration: Duration(milliseconds: 500 + delayMs),
        curve: Curves.easeOutCubic,
        builder: (context, f, _) => LayoutBuilder(
          builder: (context, c) => Column(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (isActive && value > 0)
                Container(
                  margin: const EdgeInsets.only(bottom: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: AppColors.textDark, borderRadius: BorderRadius.circular(8)),
                  child: Text('${value.round()}',
                      style: const TextStyle(fontSize: 9.5, fontWeight: FontWeight.w700, color: Colors.white)),
                ),
              Container(
                width: 14,
                height: (c.maxHeight - (isActive && value > 0 ? 24 : 0)) * f,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(7),
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: isPeak
                        ? const [AppColors.danger, AppColors.amber]
                        : const [AppColors.accentMint, AppColors.primary],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// 초록 그라데이션 카드: 총 스쿼트 횟수 + 목표 달성률 링
class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.reps, required this.percent});

  final int reps;
  final int percent;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 16),
      decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('총 스쿼트 횟수', style: TextStyle(fontSize: 11, color: Colors.white70)),
                const SizedBox(height: 4),
                RichText(
                  text: TextSpan(
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800),
                    children: [
                      TextSpan(text: '$reps', style: const TextStyle(fontSize: 30)),
                      const TextSpan(text: ' 회', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.white70)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          SizedBox(
            width: 64,
            height: 64,
            child: Stack(
              alignment: Alignment.center,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: percent / 100),
                  duration: const Duration(milliseconds: 800),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, __) => SizedBox(
                    width: 64,
                    height: 64,
                    child: CircularProgressIndicator(
                      value: v,
                      strokeWidth: 7,
                      strokeCap: StrokeCap.round,
                      backgroundColor: Colors.white24,
                      valueColor: const AlwaysStoppedAnimation(AppColors.accentMint),
                    ),
                  ),
                ),
                Container(
                  width: 40,
                  height: 40,
                  alignment: Alignment.center,
                  decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                  child: Text('$percent%', style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _KcalCard extends StatelessWidget {
  const _KcalCard({required this.label, required this.value, required this.icon, required this.background, required this.iconColor});

  final String label;
  final int value;
  final IconData icon;
  final Color background;
  final Color iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 18),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
            child: Icon(icon, size: 22, color: iconColor),
          ),
          const SizedBox(height: 10),
          Text(label, style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          const SizedBox(height: 8),
          Text('$value', style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const Text('kcal', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}
