import '../../models/user_profile.dart';
import 'package:flutter/material.dart';

import '../../utils/camera_permission.dart';
import 'package:provider/provider.dart';

import '../../providers/profile_provider.dart';
import '../../providers/workout_provider.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';
import '../../../db_test_page.dart';
import '../../../pose_camera_page.dart';
import '../../../widgets/time_input_dialog.dart';
import '../../widgets/profile_avatar.dart';

/// 마이페이지 (Figma: 마이페이지)
class MyPageTab extends StatelessWidget {
  const MyPageTab({super.key, required this.onBack});

  final VoidCallback onBack;

  @override
  Widget build(BuildContext context) {
    final profile = context.watch<ProfileProvider>();
    final user = profile.user;
    final summary = context.watch<WorkoutProvider>().summary;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: ScreenHeader(title: '마이페이지', onBack: onBack),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 14, 20, 16),
            children: [
              GestureDetector(
                onTap: () => Navigator.of(context).pushNamed('/profile-edit'),
                onLongPress: () => _openDevTools(context), // 숨겨진 개발자 도구 (자세 인식 테스트, DB 확인)
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(20)),
                  child: Row(
                    children: [
                      ProfileAvatar(user: user, size: 46, radius: 14, fontSize: 18, color: Colors.white24),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(user.name.isEmpty ? '이름을 설정해 주세요' : user.name,
                                style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w800)),
                            if (user.gender != null) ...[
                              const SizedBox(height: 2),
                              Text('${user.gender!.label}성', style: const TextStyle(color: Colors.white70, fontSize: 10.5)),
                            ],
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right_rounded, color: Colors.white),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(child: StatTile(value: '${summary.totalSessions}', label: '총 세션')),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: '${summary.totalReps}', label: '총 횟수')),
                  const SizedBox(width: 8),
                  Expanded(child: StatTile(value: '${summary.bestStreakDays}일', label: '연속 기록')),
                ],
              ),
              _section('계정'),
              _group([
                _row(Icons.person_outline_rounded, '프로필 수정', onTap: () => Navigator.of(context).pushNamed('/profile-edit')),
                _row(
                  Icons.notifications_none_rounded,
                  '알림 설정',
                  trailing: Switch(
                    value: user.notificationsEnabled,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) async {
                      final ok = await profile.setNotifications(v);
                      if (!ok && context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
                            content: Text('알림 권한이 없어요. 설정 앱에서 SquatCoach 알림을 허용해 주세요.')));
                      }
                    },
                  ),
                ),
                if (user.notificationsEnabled)
                  _row(
                    Icons.schedule_rounded,
                    '알림 시간',
                    trailing: Text(
                      '${user.reminderHour.toString().padLeft(2, '0')}:${user.reminderMinute.toString().padLeft(2, '0')}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.textDark),
                    ),
                    onTap: () async {
                      final picked = await showTimeInputDialog(
                          context, TimeOfDay(hour: user.reminderHour, minute: user.reminderMinute));
                      if (picked != null) await profile.setReminderTime(picked.hour, picked.minute);
                    },
                  ),
              ]),
              _section('운동 중 안내'),
              _group([
                _row(
                  Icons.record_voice_over_outlined,
                  '음성 안내',
                  sub: '정자세 횟수를 세어주고, 오류가 나면 말로 알려줘요',
                  trailing: Switch(
                    value: user.voiceEnabled,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => profile.setVoice(v),
                  ),
                ),
                _row(
                  Icons.notifications_active_outlined,
                  '경고음',
                  sub: '멀리서도 알 수 있게 소리로 알려줘요',
                  trailing: Switch(
                    value: user.soundEnabled,
                    activeColor: Colors.white,
                    activeTrackColor: AppColors.primary,
                    onChanged: (v) => profile.setSound(v),
                  ),
                ),
              ]),
              _section('운동 설정'),
              _group([
                _row(Icons.local_fire_department_outlined, '칼로리 활동',
                    sub: '일간 · 주간 · 월간 소모 칼로리', onTap: () => Navigator.of(context).pushNamed('/calories')),
                _row(Icons.photo_camera_outlined, '카메라 재캘리브레이션',
                    sub: '카메라 위치를 다시 맞추고 영점 측정하기', onTap: () async {
                      if (await ensureCameraPermission(context) && context.mounted) {
                        Navigator.of(context).pushNamed('/camera-setup');
                      }
                    }),
                _row(Icons.accessibility_new_rounded, '목표 반복 횟수 설정',
                    trailing: Text('세트당 ${user.targetRepsPerSet}회',
                        style: const TextStyle(fontSize: 11, color: AppColors.textMuted)),
                    onTap: () => _editTargetReps(context, profile)),
              ]),
              _section('기타'),
              _group([
                _row(null, '공지사항',
                    onTap: () => ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('새 공지사항이 없어요')))),
                _row(null, '로그아웃', danger: true, onTap: () => _confirmReset(context, profile)),
              ]),
              const SizedBox(height: 18),
              const Center(child: Text('Squat Coach v1.0.0', style: TextStyle(fontSize: 10, color: AppColors.textFaint))),
            ],
          ),
        ),
      ],
    );
  }

  Widget _section(String text) => Padding(
        padding: const EdgeInsets.fromLTRB(2, 18, 0, 8),
        child: Text(text, style: const TextStyle(fontSize: 10.5, fontWeight: FontWeight.w700, color: AppColors.textMuted)),
      );

  Widget _group(List<Widget> rows) {
    final children = <Widget>[];
    for (var i = 0; i < rows.length; i++) {
      children.add(rows[i]);
      if (i != rows.length - 1) {
        children.add(const Divider(height: 1, thickness: 1, color: AppColors.cardBorder, indent: 14, endIndent: 14));
      }
    }
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(children: children),
    );
  }

  Widget _row(IconData? icon, String title, {String? sub, Widget? trailing, VoidCallback? onTap, bool danger = false}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            if (icon != null) ...[IconTile(icon: icon, size: 34), const SizedBox(width: 12)],
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w700,
                        color: danger ? AppColors.danger : AppColors.textDark,
                      )),
                  if (sub != null) ...[
                    const SizedBox(height: 2),
                    Text(sub, style: const TextStyle(fontSize: 10, color: AppColors.textMuted)),
                  ],
                ],
              ),
            ),
            if (trailing != null)
              trailing
            else if (!danger)
              const Icon(Icons.chevron_right_rounded, size: 20, color: AppColors.textFaint),
          ],
        ),
      ),
    );
  }

  void _openDevTools(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt_outlined),
              title: const Text('자세 인식 테스트'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const PoseCameraPage()));
              },
            ),
            ListTile(
              leading: const Icon(Icons.storage_outlined),
              title: const Text('DB 테스트 · 가짜 기록 넣기'),
              onTap: () {
                Navigator.of(ctx).pop();
                Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DbTestPage()));
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTargetReps(BuildContext context, ProfileProvider profile) async {
    var value = profile.user.targetRepsPerSet;
    final result = await showDialog<int>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
          title: const Text('목표 반복 횟수', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
          content: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () => setState(() => value = (value - 1).clamp(1, 50).toInt()),
                icon: const Icon(Icons.remove_circle_outline, color: AppColors.primary),
              ),
              Text('세트당 $value회', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
              IconButton(
                onPressed: () => setState(() => value = (value + 1).clamp(1, 50).toInt()),
                icon: const Icon(Icons.add_circle_outline, color: AppColors.primary),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('취소')),
            TextButton(onPressed: () => Navigator.of(ctx).pop(value), child: const Text('저장')),
          ],
        ),
      ),
    );
    if (result != null) {
      await profile.updateProfile(targetRepsPerSet: result);
    }
  }

  /// 로그인이 없는 온디바이스 구조라서, "로그아웃"은 프로필을 지우고 처음 화면으로 돌아가는 동작으로 처리합니다.
  Future<void> _confirmReset(BuildContext context, ProfileProvider profile) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(AppRadius.card)),
        title: const Text('로그아웃 하시겠어요?', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
        content: const Text('프로필과 운동 기록이 모두 초기화되고 처음 화면으로 돌아가요.', style: TextStyle(fontSize: 12.5)),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(false), child: const Text('취소')),
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(true),
            child: const Text('로그아웃', style: TextStyle(color: AppColors.danger)),
          ),
        ],
      ),
    );
    if (ok == true) {
      final workout = context.read<WorkoutProvider>();
      await profile.reset();
      await workout.reset();
      if (context.mounted) {
        Navigator.of(context).pushNamedAndRemoveUntil('/profile', (route) => false);
      }
    }
  }
}
