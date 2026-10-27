import 'package:flutter/material.dart';

import '../db/app_database.dart';
import '../db/fake_data.dart';
import '../models/user.dart';
import '../models/workout_session.dart';
import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/weekly_bar_chart.dart';
import 'day_detail_page.dart';

/// 마이페이지: 프로필 + 주간 요약 + 주간 차트 + 최근 기록
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  final _db = AppDatabase.instance;

  bool _loading = true;
  List<User> _users = [];
  User? _user;
  Map<DateTime, DaySummary> _byDay = {};
  DateTime _weekStart = weekStartOf(DateTime.now());
  ChartMetric _metric = ChartMetric.reps;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// DB에서 사용자와 운동 기록을 다시 읽어옴
  Future<void> _load({int? userId}) async {
    final users = await _db.getAllUsers();
    User? user;
    if (users.isNotEmpty) {
      final wantId = userId ?? _user?.id;
      user = users.firstWhere((u) => u.id == wantId,
          orElse: () => users.first);
    }
    final sessions = user == null
        ? <WorkoutSession>[]
        : await _db.getSessionsByUser(user.id!);
    if (!mounted) return;
    setState(() {
      _users = users;
      _user = user;
      _byDay = groupByDay(sessions);
      _loading = false;
    });
  }

  Future<void> _insertDemo() async {
    setState(() => _loading = true);
    await insertFakeData();
    await _load();
  }

  bool get _isCurrentWeek => _weekStart == weekStartOf(DateTime.now());

  void _moveWeek(int delta) => setState(() {
        _weekStart = DateTime(
            _weekStart.year, _weekStart.month, _weekStart.day + 7 * delta);
      });

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
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DayDetailPage(day: day, userName: _user!.name),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('마이페이지',
            style: TextStyle(fontWeight: FontWeight.w700)),
        actions: [
          if (_users.length > 1)
            PopupMenuButton<int>(
              tooltip: '사용자 바꾸기',
              icon: const Icon(Icons.switch_account_outlined),
              onSelected: (id) => _load(userId: id),
              itemBuilder: (_) => [
                for (final u in _users)
                  CheckedPopupMenuItem(
                    value: u.id!,
                    checked: u.id == _user?.id,
                    child: Text(u.name),
                  ),
              ],
            ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _user == null
              ? _EmptyState(onInsert: _insertDemo)
              : RefreshIndicator(onRefresh: _load, child: _buildContent()),
    );
  }

  Widget _buildContent() {
    final user = _user!;
    final week = weekDays(_byDay, _weekStart);
    final ws = WeekSummary(week);
    final recent = _byDay.values.toList()
      ..sort((a, b) => b.date.compareTo(a.date));

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        _ProfileCard(user: user, totalDays: _byDay.length),

        // ---------- 주간 요약 ----------
        SectionTitle(_isCurrentWeek ? '이번 주 요약' : '${formatWeekRange(_weekStart)} 요약'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            StatTile(
              label: '총 횟수',
              value: '${ws.totalReps}',
              unit: '회',
              icon: Icons.fitness_center,
            ),
            StatTile(
              label: '운동한 날',
              value: '${ws.activeDays}',
              unit: '/ 7일',
              icon: Icons.calendar_today_outlined,
            ),
            StatTile(
              label: '평균 자세 점수',
              value: ws.setCount == 0 ? '-' : ws.averageScore.toStringAsFixed(1),
              unit: ws.setCount == 0 ? '' : '점',
              icon: Icons.insights,
            ),
            StatTile(
              label: '정확도',
              value: ws.totalReps == 0 ? '-' : ws.accuracy.toStringAsFixed(0),
              unit: ws.totalReps == 0 ? '' : '%',
              icon: Icons.track_changes,
            ),
          ],
        ),

        // ---------- 주간 차트 ----------
        const SectionTitle('주간 통계'),
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
                  segments: const [
                    ButtonSegment(value: ChartMetric.reps, label: Text('스쿼트 횟수')),
                    ButtonSegment(value: ChartMetric.score, label: Text('평균 점수')),
                  ],
                  selected: {_metric},
                  onSelectionChanged: (s) => setState(() => _metric = s.first),
                ),
              ),
              const SizedBox(height: 14),
              WeeklyBarChart(days: week, metric: _metric, onTapDay: _openDay),
              const SizedBox(height: 6),
              const Text(
                '막대를 누르면 그날의 세트별 기록을 볼 수 있어요',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 12, color: AppColors.textMuted),
              ),
            ],
          ),
        ),

        // ---------- 최근 기록 ----------
        const SectionTitle('최근 기록'),
        if (recent.isEmpty)
          const Padding(
            padding: EdgeInsets.all(24),
            child: Text('아직 운동 기록이 없어요',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textMuted)),
          )
        else
          for (final day in recent.take(14)) ...[
            _DayTile(day: day, onTap: () => _openDay(day)),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.totalDays});

  final User user;
  final int totalDays;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          CircleAvatar(
            radius: 30,
            backgroundColor: AppColors.seriesSoft,
            child: Text(
              user.name.characters.first,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.name,
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    _Chip('${user.age}세'),
                    _Chip('${user.heightCm.toStringAsFixed(1)}cm'),
                    _Chip('${user.weightKg.toStringAsFixed(1)}kg'),
                  ],
                ),
              ],
            ),
          ),
          Column(
            children: [
              Text(
                '$totalDays',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Text('누적 운동일',
                  style: TextStyle(fontSize: 11, color: AppColors.textMuted)),
            ],
          ),
        ],
      ),
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip(this.text);
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(text,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
    );
  }
}

class _DayTile extends StatelessWidget {
  const _DayTile({required this.day, required this.onTap});

  final DaySummary day;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
      child: Row(
        children: [
          // 날짜 블록
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 6),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Column(
              children: [
                Text('${day.date.day}',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    )),
                Text('${day.date.month}월 ${weekdayKo(day.date)}',
                    style: const TextStyle(
                        fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${day.setCount}세트 · ${day.totalReps}회',
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '정확도 ${day.accuracy.toStringAsFixed(0)}% · ${formatDuration(day.totalSec)}',
                  style: const TextStyle(
                      fontSize: 12.5, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          GradeBadge(score: day.averageScore),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onInsert});
  final VoidCallback onInsert;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bar_chart_rounded,
                size: 56, color: AppColors.textMuted),
            const SizedBox(height: 12),
            const Text('저장된 사용자와 운동 기록이 없어요',
                style: TextStyle(fontSize: 16, color: AppColors.textPrimary)),
            const SizedBox(height: 6),
            const Text('테스트용 데이터를 넣고 화면을 확인해 보세요',
                style: TextStyle(fontSize: 13, color: AppColors.textMuted)),
            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: onInsert,
              icon: const Icon(Icons.add),
              label: const Text('가짜 데이터 넣기'),
            ),
          ],
        ),
      ),
    );
  }
}
