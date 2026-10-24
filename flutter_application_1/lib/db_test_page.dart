import 'package:flutter/material.dart';

import 'db/app_database.dart';
import 'db/fake_data.dart';
import 'models/user.dart';
import 'models/workout_session.dart';

/// 로컬 DB 저장·조회 테스트 화면
class DbTestPage extends StatefulWidget {
  const DbTestPage({super.key});

  @override
  State<DbTestPage> createState() => _DbTestPageState();
}

class _DbTestPageState extends State<DbTestPage> {
  final _db = AppDatabase.instance;

  List<User> _users = [];
  final Map<int, List<WorkoutSession>> _sessions = {};
  String _status = '버튼을 눌러 테스트하세요.';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _run(Future<String> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      final message = await action();
      await _reload();
      setState(() => _status = message);
    } catch (e) {
      setState(() => _status = '❌ 오류: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _reload() async {
    final users = await _db.getAllUsers();
    _sessions.clear();
    for (final u in users) {
      _sessions[u.id!] = await _db.getSessionsByUser(u.id!);
    }
    if (mounted) setState(() => _users = users);
  }

  Future<String> _insertFake() async {
    final (u, s) = await insertFakeData();
    final (totalU, totalS) = await _db.counts();
    return '✅ 사용자 $u명, 운동 기록 $s개 추가\n'
        '현재 DB: 사용자 $totalU명 / 운동 기록 $totalS개';
  }

  Future<String> _verify() async {
    final errors = await verifyRoundTrip();
    return errors.isEmpty
        ? '✅ 검증 통과: 저장한 값과 조회한 값이 모두 일치하고,\n'
            '사용자 삭제 시 운동 기록도 함께 삭제됩니다.'
        : '❌ 검증 실패\n${errors.join('\n')}';
  }

  Future<String> _clear() async {
    await _db.clearAll();
    return '🗑 모든 데이터를 삭제했습니다.';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('로컬 DB 테스트')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton(
                  onPressed: _busy ? null : () => _run(_insertFake),
                  child: const Text('가짜 데이터 넣기'),
                ),
                FilledButton.tonal(
                  onPressed: _busy ? null : () => _run(_verify),
                  child: const Text('저장·조회 검증'),
                ),
                OutlinedButton(
                  onPressed: _busy ? null : () => _run(_clear),
                  child: const Text('전부 삭제'),
                ),
              ],
            ),
          ),
          Container(
            width: double.infinity,
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white10,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(_status),
          ),
          const SizedBox(height: 8),
          Expanded(
            child: _users.isEmpty
                ? const Center(child: Text('저장된 사용자가 없습니다.'))
                : ListView(
                    children: [
                      for (final u in _users)
                        ExpansionTile(
                          title: Text('${u.name} (id: ${u.id})'),
                          subtitle: Text(
                              '${u.age}세 · ${u.heightCm}cm · ${u.weightKg}kg · '
                              '기록 ${_sessions[u.id]?.length ?? 0}개'),
                          children: [
                            for (final s in _sessions[u.id] ?? <WorkoutSession>[])
                              ListTile(
                                dense: true,
                                title: Text(
                                    '${s.exerciseType} · ${s.totalReps}회 중 '
                                    '${s.goodReps}회 정확 '
                                    '(${s.accuracy.toStringAsFixed(0)}%)'),
                                subtitle: Text(
                                    '${_formatDate(s.startedAt)} · '
                                    '${s.durationSec}초 · '
                                    '점수 ${s.averageScore.toStringAsFixed(1)}'
                                    '${s.memo != null ? ' · ${s.memo}' : ''}'),
                              ),
                          ],
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  String _formatDate(DateTime d) =>
      '${d.month}/${d.day} ${d.hour.toString().padLeft(2, '0')}:'
      '${d.minute.toString().padLeft(2, '0')}';
}
