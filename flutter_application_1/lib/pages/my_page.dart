import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../db/app_database.dart';
import '../db/fake_data.dart';
import '../db_test_page.dart';
import '../models/user.dart';
import '../models/workout_session.dart';
import '../pose_camera_page.dart';
import '../services/notification_service.dart';
import '../state/app_events.dart';
import '../stats/workout_stats.dart';
import '../ui/app_colors.dart';
import '../widgets/common.dart';
import '../widgets/time_input_dialog.dart';

/// 마이페이지: 프로필, 누적 운동 통계, 알림 설정, 개발자 도구
class MyPage extends StatefulWidget {
  const MyPage({super.key});

  @override
  State<MyPage> createState() => _MyPageState();
}

class _MyPageState extends State<MyPage> {
  static const _kReminderOn = 'reminder_enabled';
  static const _kReminderTime = 'reminder_time'; // "HH:mm"

  final _db = AppDatabase.instance;
  bool _loading = true;
  User? _user;
  SessionTotals _all = SessionTotals(const []);
  int _streak = 0;
  WorkoutSession? _best;

  bool _reminderOn = false;
  bool _showDev = false; // 프로필을 길게 누르면 개발자 도구 표시
  TimeOfDay _reminderTime = const TimeOfDay(hour: 20, minute: 0);

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
    final user = await _db.getOrCreateDefaultUser();
    final sessions = await _db.getSessionsByUser(user.id!);
    final on = await _db.getSetting(_kReminderOn);
    final time = await _db.getSetting(_kReminderTime);
    if (!mounted) return;

    WorkoutSession? best;
    for (final s in sessions) {
      if (s.totalReps >= 5 && (best == null || s.accuracy > best.accuracy)) best = s;
    }

    setState(() {
      _user = user;
      _all = SessionTotals(sessions);
      _streak = _currentStreak(sessions);
      _best = best;
      _reminderOn = on == '1';
      if (time != null && time.contains(':')) {
        final p = time.split(':');
        _reminderTime = TimeOfDay(hour: int.parse(p[0]), minute: int.parse(p[1]));
      }
      _loading = false;
    });
  }

  /// 오늘(또는 어제)까지 연속으로 운동한 날 수
  int _currentStreak(List<WorkoutSession> sessions) {
    final days = sessions.map((s) => dayOf(s.startedAt)).toSet();
    var d = dayOf(DateTime.now());
    if (!days.contains(d)) d = DateTime(d.year, d.month, d.day - 1);
    var n = 0;
    while (days.contains(d)) {
      n++;
      d = DateTime(d.year, d.month, d.day - 1);
    }
    return n;
  }

  // ---------------- 알림 ----------------

  Future<void> _toggleReminder(bool on) async {
    final service = NotificationService.instance;
    if (on) {
      final granted = await service.requestPermission();
      if (!granted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('알림 권한이 없어요. 설정 앱 → SquatCoach → 알림에서 허용해 주세요.'),
        ));
        return;
      }
      await service.scheduleDaily(_reminderTime.hour, _reminderTime.minute);
    } else {
      await service.cancelDaily();
    }
    await _db.setSetting(_kReminderOn, on ? '1' : '0');
    if (mounted) setState(() => _reminderOn = on);
  }

  Future<void> _pickTime() async {
    final picked = await showTimeInputDialog(context, _reminderTime); // 키보드 입력 + 휠
    if (picked == null) return;
    await _db.setSetting(_kReminderTime,
        '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}');
    if (_reminderOn) {
      await NotificationService.instance.scheduleDaily(picked.hour, picked.minute);
    }
    if (mounted) setState(() => _reminderTime = picked);
  }

  String _formatTime(TimeOfDay t) {
    final ampm = t.hour < 12 ? '오전' : '오후';
    final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
    return '$ampm $h:${t.minute.toString().padLeft(2, '0')}';
  }

  // ---------------- 프로필 ----------------

  Future<void> _editProfile() async {
    final user = _user;
    if (user == null) return;
    final name = TextEditingController(text: user.name);
    final age = TextEditingController(text: '${user.age}');
    final height = TextEditingController(text: user.heightCm.toStringAsFixed(1));
    final weight = TextEditingController(text: user.weightKg.toStringAsFixed(1));

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('프로필 수정'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(controller: name, decoration: const InputDecoration(labelText: '이름')),
              TextField(
                  controller: age,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: '나이')),
              TextField(
                  controller: height,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(labelText: '키 (cm)')),
              TextField(
                  controller: weight,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: const InputDecoration(
                      labelText: '몸무게 (kg)', helperText: '소모 칼로리 계산에 사용돼요')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('취소')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('저장')),
        ],
      ),
    );
    if (saved != true) return;
    await _db.updateUser(User(
      id: user.id,
      name: name.text.trim().isEmpty ? user.name : name.text.trim(),
      age: int.tryParse(age.text) ?? user.age,
      heightCm: double.tryParse(height.text) ?? user.heightCm,
      weightKg: double.tryParse(weight.text) ?? user.weightKg,
      createdAt: user.createdAt,
    ));
  }

  // ---------------- 화면 ----------------

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.surface,
      appBar: AppBar(
        backgroundColor: AppColors.surface,
        surfaceTintColor: Colors.transparent,
        title: const Text('마이페이지', style: TextStyle(fontWeight: FontWeight.w700)),
      ),
      body: _loading ? const Center(child: CircularProgressIndicator()) : _content(),
    );
  }

  Widget _content() {
    final user = _user!;
    final all = _all;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
      children: [
        GestureDetector(
          // 숨겨진 개발자 도구: 프로필 길게 누르기
          onLongPress: () {
            HapticFeedback.mediumImpact();
            setState(() => _showDev = !_showDev);
            ScaffoldMessenger.of(context).showSnackBar(SnackBar(
              content: Text(_showDev ? '개발자 도구를 열었어요 (맨 아래)' : '개발자 도구를 숨겼어요'),
              duration: const Duration(seconds: 2),
            ));
          },
          child: _ProfileCard(user: user, onEdit: _editProfile),
        ),

        // ---------- 누적 운동 통계 ----------
        const SectionTitle('누적 운동 통계'),
        GridView.count(
          crossAxisCount: 2,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: 10,
          crossAxisSpacing: 10,
          childAspectRatio: 1.75,
          children: [
            StatTile(label: '총 스쿼트', value: '${all.totalReps}', unit: '회', icon: Icons.fitness_center),
            StatTile(
                label: '평균 정확도',
                value: all.totalReps == 0 ? '-' : all.accuracy.toStringAsFixed(0),
                unit: all.totalReps == 0 ? '' : '%',
                icon: Icons.track_changes),
            StatTile(label: '총 운동 시간', value: formatDuration(all.totalSec), icon: Icons.timer_outlined),
            StatTile(
                label: '총 소모 칼로리',
                value: formatKcal(all.caloriesKcal),
                unit: 'kcal',
                icon: Icons.local_fire_department_outlined),
            StatTile(
                label: '운동 횟수',
                value: '${all.sessionCount}',
                unit: '번 · ${all.activeDays}일',
                icon: Icons.calendar_month_outlined),
            StatTile(label: '연속 운동', value: '$_streak', unit: '일째', icon: Icons.whatshot_outlined),
          ],
        ),
        if (_best != null) ...[
          const SizedBox(height: 10),
          AppCard(
            child: Row(
              children: [
                const Icon(Icons.emoji_events_outlined, color: AppColors.textSecondary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    '최고 기록: ${formatDateKo(_best!.startedAt)} · '
                    '정확도 ${_best!.accuracy.toStringAsFixed(0)}% (${_best!.totalReps}회)',
                    style: const TextStyle(fontSize: 13.5, color: AppColors.textPrimary),
                  ),
                ),
              ],
            ),
          ),
        ],

        // ---------- 알림 설정 ----------
        const SectionTitle('알림 설정'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              SwitchListTile(
                value: _reminderOn,
                onChanged: _toggleReminder,
                title: const Text('매일 운동 알림'),
                subtitle: const Text('정해진 시간에 스쿼트할 시간을 알려 드려요'),
              ),
              ListTile(
                enabled: _reminderOn,
                title: const Text('알림 시간'),
                trailing: Text(
                  _formatTime(_reminderTime),
                  style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
                ),
                onTap: _reminderOn ? _pickTime : null,
              ),
            ],
          ),
        ),

        // ---------- 개발자 도구 (숨김) ----------
        if (_showDev) ...[
        const SectionTitle('개발자 도구'),
        AppCard(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            children: [
              ListTile(
                leading: const Icon(Icons.accessibility_new),
                title: const Text('자세 인식 테스트'),
                subtitle: const Text('뼈대·FPS만 확인'),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const PoseCameraPage())),
              ),
              ListTile(
                leading: const Icon(Icons.storage),
                title: const Text('로컬 DB 테스트'),
                subtitle: const Text('저장·조회 검증, 전부 삭제'),
                onTap: () => Navigator.push(
                    context, MaterialPageRoute(builder: (_) => const DbTestPage())),
              ),
              ListTile(
                leading: const Icon(Icons.auto_awesome_outlined),
                title: const Text('가짜 운동 기록 넣기'),
                subtitle: const Text('최근 3주치 테스트 데이터'),
                onTap: () async {
                  final messenger = ScaffoldMessenger.of(context);
                  final (_, sessions, sets) = await insertFakeData(userId: _user!.id);
                  notifyDataChanged();
                  messenger.showSnackBar(
                      SnackBar(content: Text('운동 $sessions회(세트 $sets개)를 넣었어요')));
                },
              ),
            ],
          ),
        ),
        ],
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  const _ProfileCard({required this.user, required this.onEdit});

  final User user;
  final VoidCallback onEdit;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onEdit,
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
                Text(user.name,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textPrimary,
                    )),
                const SizedBox(height: 6),
                Text(
                  '${user.age}세 · ${user.heightCm.toStringAsFixed(1)}cm · ${user.weightKg.toStringAsFixed(1)}kg',
                  style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.edit_outlined, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
