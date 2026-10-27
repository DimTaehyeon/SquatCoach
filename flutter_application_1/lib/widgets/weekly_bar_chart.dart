import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';

enum ChartMetric { reps, score }

/// 월~일 7개 막대. 막대(또는 그 열 어디든)를 누르면 onTapDay 호출
class WeeklyBarChart extends StatelessWidget {
  const WeeklyBarChart({
    super.key,
    required this.days,
    required this.metric,
    required this.onTapDay,
    this.height = 170,
  });

  final List<DaySummary> days;
  final ChartMetric metric;
  final ValueChanged<DaySummary> onTapDay;
  final double height; // 막대가 그려지는 영역 높이

  static const _valueLabelH = 20.0;
  static const _dayLabelH = 34.0;
  static const _axisW = 30.0;

  double _value(DaySummary d) =>
      metric == ChartMetric.reps ? d.totalReps.toDouble() : d.averageScore;

  /// 축 최댓값을 보기 좋은 숫자로 올림 (횟수: 10/20/50 단위, 점수: 100 고정)
  double get _maxY {
    if (metric == ChartMetric.score) return 100;
    final m = days.map(_value).fold<double>(0, math.max);
    if (m <= 0) return 10;
    final step = m <= 50 ? 10 : (m <= 100 ? 20 : 50);
    return (m / step).ceil() * step.toDouble();
  }

  String _fmt(double v) => v.round().toString();

  @override
  Widget build(BuildContext context) {
    final maxY = _maxY;
    final today = dayOf(DateTime.now());

    return SizedBox(
      height: _valueLabelH + height + _dayLabelH,
      child: Stack(
        children: [
          // 가로 눈금선과 축 숫자 (0, 중간, 최댓값)
          for (final f in const [0.0, 0.5, 1.0]) ...[
            Positioned(
              left: _axisW,
              right: 0,
              top: _valueLabelH + height * (1 - f),
              child: Container(
                height: 1,
                color: f == 0 ? AppColors.axis : AppColors.grid,
              ),
            ),
            Positioned(
              left: 0,
              width: _axisW - 8,
              top: _valueLabelH + height * (1 - f) - 7,
              child: Text(
                _fmt(maxY * f),
                textAlign: TextAlign.right,
                style: const TextStyle(fontSize: 10, color: AppColors.textMuted),
              ),
            ),
          ],
          // 막대 7개
          Positioned.fill(
            left: _axisW,
            child: Row(
              children: [
                for (final d in days)
                  Expanded(
                    child: _BarColumn(
                      day: d,
                      value: _value(d),
                      maxY: maxY,
                      barAreaH: height,
                      valueLabelH: _valueLabelH,
                      dayLabelH: _dayLabelH,
                      isToday: d.date == today,
                      unit: metric == ChartMetric.reps ? '회' : '점',
                      onTap: () => onTapDay(d),
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _BarColumn extends StatelessWidget {
  const _BarColumn({
    required this.day,
    required this.value,
    required this.maxY,
    required this.barAreaH,
    required this.valueLabelH,
    required this.dayLabelH,
    required this.isToday,
    required this.unit,
    required this.onTap,
  });

  final DaySummary day;
  final double value;
  final double maxY;
  final double barAreaH;
  final double valueLabelH;
  final double dayLabelH;
  final bool isToday;
  final String unit;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final empty = day.isEmpty;
    // 값이 아주 작아도 눌러 볼 수 있게 최소 4px
    final barH = empty ? 0.0 : math.max(4.0, value / maxY * barAreaH);
    final weekday = weekdayKo(day.date);

    return Semantics(
      button: true,
      label: empty
          ? '$weekday요일 기록 없음'
          : '$weekday요일 ${value.round()}$unit, 눌러서 세트별 기록 보기',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque, // 막대 위 빈 공간을 눌러도 반응
        onTap: onTap,
        child: Column(
          children: [
            SizedBox(
              height: valueLabelH,
              child: Center(
                child: Text(
                  empty ? '' : value.round().toString(),
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            SizedBox(
              height: barAreaH,
              child: Align(
                alignment: Alignment.bottomCenter,
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 450),
                  curve: Curves.easeOutCubic,
                  width: 20,
                  height: barH,
                  decoration: const BoxDecoration(
                    color: AppColors.series,
                    borderRadius: BorderRadius.vertical(top: Radius.circular(4)),
                  ),
                ),
              ),
            ),
            SizedBox(
              height: dayLabelH,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    weekday,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color: isToday
                          ? AppColors.textPrimary
                          : AppColors.textSecondary,
                    ),
                  ),
                  Text(
                    isToday ? '오늘' : '${day.date.day}',
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: isToday ? FontWeight.w700 : FontWeight.w400,
                      color:
                          isToday ? AppColors.textPrimary : AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
