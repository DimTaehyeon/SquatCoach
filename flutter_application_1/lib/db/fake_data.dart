import 'dart:math';

import '../models/user.dart';
import '../models/workout_session.dart';
import 'app_database.dart';

/// 가짜 사용자 3명 + 최근 3주 동안의 운동 기록을 DB에 넣음
/// - 하루에 2~4세트 (운동 세션 1개 = 세트 1개)
/// - 운동 안 한 날도 섞여 있어서 주간 차트에 빈 날이 생김
/// 반환값: 넣은 사용자 수, 세션(세트) 수
Future<(int, int)> insertFakeData() async {
  final db = AppDatabase.instance;
  final random = Random();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);

  final fakeUsers = [
    User(name: '김철수', age: 24, heightCm: 175.2, weightKg: 70.5, createdAt: now),
    User(name: '이영희', age: 31, heightCm: 162.0, weightKg: 54.3, createdAt: now),
    User(name: '박민수', age: 45, heightCm: 180.8, weightKg: 85.0, createdAt: now),
  ];
  const memos = ['무릎이 안쪽으로 모임', '허리 각도 좋았음', '마지막에 힘 빠짐', null, null];

  var sessionCount = 0;
  for (final user in fakeUsers) {
    final userId = await db.insertUser(user);

    for (var daysAgo = 0; daysAgo < 21; daysAgo++) {
      // 오늘은 항상 기록이 있고, 나머지 날은 약 35% 확률로 쉼
      if (daysAgo != 0 && random.nextDouble() < 0.35) continue;

      final date = DateTime(today.year, today.month, today.day - daysAgo);
      var time = date.add(Duration(hours: 7 + random.nextInt(13), minutes: random.nextInt(60)));
      final setCount = 2 + random.nextInt(3); // 2~4세트

      for (var s = 0; s < setCount; s++) {
        final total = 8 + random.nextInt(8); // 8~15회
        final good = total - random.nextInt(5); // 0~4회 실수
        // 정확한 횟수가 많을수록 점수가 높게
        final score = (55 + good / total * 38 + random.nextDouble() * 7)
            .clamp(0, 100)
            .toDouble();
        final duration = total * (3 + random.nextInt(3)) + random.nextInt(20);

        await db.insertSession(WorkoutSession(
          userId: userId,
          exerciseType: 'squat',
          startedAt: time,
          durationSec: duration,
          totalReps: total,
          goodReps: good,
          averageScore: score,
          memo: memos[random.nextInt(memos.length)],
        ));
        sessionCount++;
        // 다음 세트는 운동 시간 + 휴식 1~3분 뒤
        time = time.add(Duration(seconds: duration + 60 + random.nextInt(120)));
      }
    }
  }
  return (fakeUsers.length, sessionCount);
}

/// 저장한 값과 다시 읽은 값이 정확히 같은지 확인
/// 실패한 항목이 있으면 그 내용을 담은 리스트를 돌려줌 (비어 있으면 통과)
Future<List<String>> verifyRoundTrip() async {
  final db = AppDatabase.instance;
  final errors = <String>[];

  final original = User(
    name: '검증용사용자',
    age: 29,
    heightCm: 170.5,
    weightKg: 65.25,
    createdAt: DateTime(2026, 10, 16, 20, 0, 0),
  );
  final userId = await db.insertUser(original);
  final loaded = await db.getUser(userId);

  if (loaded == null) {
    errors.add('User: 저장한 id($userId)로 조회가 안 됨');
  } else {
    if (loaded.name != original.name) errors.add('User.name 불일치');
    if (loaded.age != original.age) errors.add('User.age 불일치');
    if (loaded.heightCm != original.heightCm) errors.add('User.heightCm 불일치');
    if (loaded.weightKg != original.weightKg) errors.add('User.weightKg 불일치');
    if (loaded.createdAt != original.createdAt) {
      errors.add('User.createdAt 불일치');
    }
  }

  final session = WorkoutSession(
    userId: userId,
    exerciseType: 'squat',
    startedAt: DateTime(2026, 10, 16, 20, 5, 0),
    durationSec: 180,
    totalReps: 15,
    goodReps: 12,
    averageScore: 87.5,
    memo: '검증',
  );
  await db.insertSession(session);
  final sessions = await db.getSessionsByUser(userId);

  if (sessions.length != 1) {
    errors.add('Session: 1개 저장했는데 ${sessions.length}개 조회됨');
  } else {
    final s = sessions.first;
    if (s.totalReps != 15 || s.goodReps != 12) errors.add('Session 횟수 불일치');
    if (s.averageScore != 87.5) errors.add('Session 점수 불일치');
    if (s.memo != '검증') errors.add('Session 메모 불일치');
    if (s.accuracy != 80) errors.add('Session 정확도 계산 오류');
  }

  // 사용자를 지우면 그 사용자의 운동 기록도 같이 지워지는지 (외래키 CASCADE)
  await db.deleteUser(userId);
  final afterDelete = await db.getSessionsByUser(userId);
  if (afterDelete.isNotEmpty) {
    errors.add('사용자 삭제 후에도 운동 기록이 남아 있음 (CASCADE 실패)');
  }

  return errors;
}
