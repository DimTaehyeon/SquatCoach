import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../models/user.dart';
import '../models/workout_session.dart';
import '../state/app_events.dart';
import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/session_tile.dart';
import '../widgets/weekly_bar_chart.dart';
import 'ai_coach_page.dart';
import 'day_detail_page.dart';
import 'session_detail_page.dart';

/// 기록 · 메인: 운동 시작, 주간 합계, 주간 그래프, 최근 기록
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool _loading = true;
  User? _user;
  List<WorkoutSession> _sessions = [];
  Map<DateTime, DaySummary> _byDay = {};
  DateTime _weekStart = weekStartOf(DateTime.now());
  ChartMetric _metric = ChartMetric.reps;

  @override
  void initState() {
    super.initState();
    dataChanged.addListener(_load);
    _load();
  }

  @override
  void dispose() {
    dataChanged.removeListener(_load);
    super.dispose();
  }

  Future<void> _load() async {
    final db = AppDatabase.instance;
    final users = await db.getAllUsers();
    final user = users.isEmpty ? null : users.first;
    final sessions = user == null ? <WorkoutSession>[] : await db.getSessionsByUser(user.id!);
    if (!mounted) return;
    setState(() {
      _user = user;
      _sessions = sessions;
      _byDay = groupByDay(sessions);
      _loading = false;
    });
  }

  bool get _isCurrentWeek => _weekStart == weekStartOf(DateTime.now());

  void _moveWeek(int delta) => setState(() {
        _weekStart = DateTime(_weekStart.year, _weekStart.month, _weekStart.day + 7 * delta);
      });

  void _startWorkout() {
    Navigator.push(context, MaterialPageRoute(builder: (_) => const WorkoutPage()));
  }

  void _openDay(DaySummary day) {
    if (day.isEmpty) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(
          content: Text('${formatDateKo(day.date)}에는 운동 기록이 없어요'),
          duration: const Duration(seconds: 2),
        ));
      return;
    }
    if (day.sessionCount == 1) {
      _openSession(day.sessions.first);
      return;
    }
    Navigator.push(context, MaterialPageRoute(builder: (_) => DayDetailPage(day: day)));
  }

  void _openSession(WorkoutSession s) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => SessionDetailPage(sessionId: s.id!)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('SquatCoach', style: TextStyle(fontWeight: FontWeight.w800)),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(onRefresh: _load, child: _content()),
    );
  }

  Widget _content() {
    final week = weekDays(_byDay, _weekStart);
    final wt = weekTotals(week);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _StartCard(
          name: _user?.name,
          todayReps: _byDay[dayOf(DateTime.now())]?.totalReps ?? 0,
          onStart: _startWorkout,
        ),

        // ---------- 주간 합계 ----------
        SectionTitle(_isCurrentWeek ? '이번 주 합계' : '${formatWeekRange(_weekStart)} 합계'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            StatTile(label: '총 횟수', value: '${wt.totalReps}', unit: '회', icon: Icons.fitness_center),
            StatTile(
                label: '평균 정확도',
                value: wt.totalReps == 0 ? '-' : wt.accuracy.toStringAsFixed(0),
                unit: wt.totalReps == 0 ? '' : '%',
                icon: Icons.track_changes),
            StatTile(label: '운동 시간', value: formatDuration(wt.totalSec), icon: Icons.timer_outlined),
            StatTile(
                label: '소모 칼로리',
                value: formatKcal(wt.caloriesKcal),
                unit: 'kcal',
                icon: Icons.local_fire_department_outlined),
          ],
        ),

        // ---------- 주간 그래프 ----------
        const SectionTitle('주간 그래프'),
        AppCard(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  IconButton(
                    tooltip: '이전 주',
                    onPressed: () => _moveWeek(-1),
                    icon: const Icon(Icons.chevron_left),
                  ),
                  Expanded(
                    child: Text(
                      formatWeekRange(_weekStart),
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: '다음 주',
                    onPressed: _isCurrentWeek ? null : () => _moveWeek(1),
                    icon: const Icon(Icons.chevron_right),
                  ),
                ],
              ),
              Center(
                child: SegmentedButton<ChartMetric>(
                  showSelectedIcon: false,
                  style: const ButtonStyle(visualDensity: VisualDensity.compact),
                  segments: [
                    for (final m in ChartMetric.values)
                      ButtonSegment(value: m, label: Text(m.label)),
                  ],
                  selected: {_metric},
                  onSelectionChanged: (s) => setState(() => _metric = s.first),
                ),
              ),
              const SizedBox(height: 14),
              WeeklyBarChart(days: week, metric: _metric, onTapDay: _openDay),
              const SizedBox(height: 6),
              const Text(
                '막대를 누르면 그날의 운동 기록을 볼 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),

        // ---------- 최근 기록 ----------
        const SectionTitle('최근 기록'),
        if (_sessions.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('아직 운동 기록이 없어요. 위의 운동 시작을 눌러 보세요!',
                textAlign: TextAlign.center, style: TextStyle(color: AppColors.textMuted)),
          )
        else
          for (final s in _sessions.take(10)) ...[
            SessionTile(session: s, onTap: () => _openSession(s)),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _StartCard extends StatelessWidget {
  const _StartCard({required this.name, required this.todayReps, required this.onStart});

  final String? name;
  final int todayReps;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            name == null ? '오늘도 스쿼트 해볼까요?' : '$name님, 오늘도 스쿼트 해볼까요?',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            todayReps == 0 ? '오늘은 아직 운동 기록이 없어요' : '오늘 $todayReps회 했어요',
            style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 14),
          FilledButton.icon(
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            onPressed: onStart,
            icon: const Icon(Icons.play_arrow_rounded),
            label: const Text('운동 시작', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700)),
          ),
          const SizedBox(height: 8),
          const Text(
            '폰을 허리 높이에 세우고, 2~3m 떨어진 정면에 서 주세요',
            style: TextStyle(fontSize: 12, color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }
}
