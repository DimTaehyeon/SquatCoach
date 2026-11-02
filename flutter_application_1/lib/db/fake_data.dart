import 'dart:math';

import '../config/calories.dart';
import '../config/squat_criteria.dart';
import '../models/user.dart';
import '../models/workout_session.dart';
import 'app_database.dart';

/// 가짜 사용자 3명 + 최근 3주 동안의 운동 기록을 DB에 넣음
/// - 운동한 날은 세션 1~2개, 세션마다 2~4세트, 세트마다 8~15회
/// - 반복마다 판정 기준 문서의 오류 이름으로 결과를 만듦
/// [userId]를 주면 그 사용자 한 명에게만 기록을 넣음 (마이페이지 '가짜 운동 기록 넣기')
/// 반환값: 사용자 수, 세션 수, 세트 수
Future<(int, int, int)> insertFakeData({int? userId}) async {
  final db = AppDatabase.instance;
  final random = Random();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final existing = userId == null ? null : await db.getUser(userId);
  final fakeUsers = existing != null ? [existing] : [
    User(name: '김철수', age: 24, heightCm: 175.2, weightKg: 70.5, createdAt: now),
    User(name: '이영희', age: 31, heightCm: 162.0, weightKg: 54.3, createdAt: now),
    User(name: '박민수', age: 45, heightCm: 180.8, weightKg: 85.0, createdAt: now),
  ];
  final judged = SquatFault.values.where((f) => f.role == CheckRole.judged).toList();
  final refs = SquatFault.values.where((f) => f.role == CheckRole.reference).toList();

  var sessionCount = 0;
  var setCount = 0;
  for (final user in fakeUsers) {
    final uid = existing != null ? existing.id! : await db.insertUser(user);

    for (var daysAgo = 0; daysAgo < 21; daysAgo++) {
      if (daysAgo != 0 && random.nextDouble() < 0.35) continue; // 쉬는 날
      final date = DateTime(today.year, today.month, today.day - daysAgo);
      final sessionsToday = random.nextDouble() < 0.2 ? 2 : 1;
      var time = date.add(Duration(hours: 7 + random.nextInt(6), minutes: random.nextInt(60)));

      for (var s = 0; s < sessionsToday; s++) {
        final sets = <WorkoutSet>[];
        var activeSec = 0;
        final setTotal = 2 + random.nextInt(3);

        for (var si = 1; si <= setTotal; si++) {
          final setStart = time;
          final repCount = 8 + random.nextInt(8);
          final reps = <RepRecord>[];
          for (var r = 1; r <= repCount; r++) {
            time = time.add(Duration(seconds: 3 + random.nextInt(3)));
            final bad = random.nextDouble() < 0.2;
            final faults = bad ? [judged[random.nextInt(judged.length)].label] : <String>[];
            final warnings = random.nextDouble() < 0.15
                ? [refs[random.nextInt(refs.length)].label]
                : <String>[];
            reps.add(RepRecord(
              repIndex: r,
              endedAt: time,
              isGood: !bad,
              faults: faults,
              warnings: warnings,
              score: bad ? 50 + random.nextDouble() * 25 : 78 + random.nextDouble() * 22,
            ));
          }
          final set = WorkoutSet.fromReps(
              setIndex: si, startedAt: setStart, endedAt: time, reps: reps);
          sets.add(set);
          activeSec += set.durationSec;
          setCount++;
          time = time.add(Duration(seconds: 60 + random.nextInt(60))); // 휴식
        }

        await db.saveWorkout(WorkoutSession.fromSets(
          userId: uid,
          sets: sets,
          caloriesKcal: caloriesKcal(weightKg: user.weightKg, activeSeconds: activeSec),
        ));
        sessionCount++;
        time = time.add(Duration(hours: 3 + random.nextInt(5)));
      }
    }
  }
  return (existing != null ? 0 : fakeUsers.length, sessionCount, setCount);
}

/// 저장한 값과 다시 읽은 값이 같은지 확인. 실패 항목 목록을 돌려줌 (비어 있으면 통과)
Future<List<String>> verifyRoundTrip() async {
  final db = AppDatabase.instance;
  final errors = <String>[];

  final user = User(
    name: '검증용사용자',
    age: 29,
    heightCm: 170.5,
    weightKg: 65.25,
    createdAt: DateTime(2026, 10, 16, 20, 0, 0),
  );
  final userId = await db.insertUser(user);
  final loadedUser = await db.getUser(userId);
  if (loadedUser == null) {
    errors.add('User: 저장한 id($userId)로 조회가 안 됨');
  } else if (loadedUser.name != user.name ||
      loadedUser.weightKg != user.weightKg ||
      loadedUser.createdAt != user.createdAt) {
    errors.add('User 값 불일치');
  }

  final start = DateTime(2026, 10, 16, 20, 5, 0);
  final reps = [
    for (var i = 1; i <= 10; i++)
      RepRecord(
        repIndex: i,
        endedAt: start.add(Duration(seconds: i * 4)),
        isGood: i <= 8,
        faults: i <= 8 ? const [] : const ['무릎 덜 굽힘'],
        warnings: i == 3 ? const ['발뒤꿈치 들림'] : const [],
        score: i <= 8 ? 90 : 60,
      ),
  ];
  final set1 = WorkoutSet.fromReps(
      setIndex: 1, startedAt: start, endedAt: start.add(const Duration(seconds: 40)), reps: reps);
  final session = WorkoutSession.fromSets(userId: userId, sets: [set1], caloriesKcal: 12.5);
  final sessionId = await db.saveWorkout(session);
  final loaded = await db.getSessionDetail(sessionId);

  if (loaded == null) {
    errors.add('세션 조회 실패');
  } else {
    if (loaded.totalReps != 10 || loaded.goodReps != 8) errors.add('세션 횟수 불일치');
    if (loaded.accuracy != 80) errors.add('세션 정확도 계산 오류');
    if (loaded.caloriesKcal != 12.5) errors.add('칼로리 불일치');
    if (loaded.memo != '무릎 덜 굽힘 2회') errors.add('피드백 요약 불일치: ${loaded.memo}');
    if (loaded.sets.length != 1) {
      errors.add('세트 개수 불일치');
    } else {
      final s = loaded.sets.first;
      if (s.reps.length != 10) errors.add('반복 기록 개수 불일치');
      if (s.faultCounts['무릎 덜 굽힘'] != 2) errors.add('세트 오류 집계 불일치');
      if (s.reps[2].warnings.join() != '발뒤꿈치 들림') errors.add('참고 항목 저장 오류');
    }
  }

  // 사용자를 지우면 세션·세트·반복이 전부 같이 지워지는지 (CASCADE)
  await db.deleteUser(userId);
  if (await db.getSessionDetail(sessionId) != null) {
    errors.add('사용자 삭제 후에도 운동 기록이 남아 있음');
  }
  return errors;
}
