import 'dart:math';

import '../models/user.dart';
import '../models/workout_session.dart';
import 'app_database.dart';

/// 가짜 사용자 3명 + 사용자마다 운동 기록 5개를 DB에 넣음
/// 반환값: 넣은 사용자 수, 세션 수
Future<(int, int)> insertFakeData() async {
  final db = AppDatabase.instance;
  final random = Random();
  final now = DateTime.now();

  final fakeUsers = [
    User(name: '김철수', age: 24, heightCm: 175.2, weightKg: 70.5, createdAt: now),
    User(name: '이영희', age: 31, heightCm: 162.0, weightKg: 54.3, createdAt: now),
    User(name: '박민수', age: 45, heightCm: 180.8, weightKg: 85.0, createdAt: now),
  ];

  var sessionCount = 0;
  for (final user in fakeUsers) {
    final userId = await db.insertUser(user);

    for (var day = 0; day < 5; day++) {
      final total = 10 + random.nextInt(11); // 10~20회
      final good = total - random.nextInt(6); // 0~5회 실수
      await db.insertSession(WorkoutSession(
        userId: userId,
        exerciseType: 'squat',
        startedAt: now.subtract(Duration(days: day, hours: random.nextInt(5))),
        durationSec: 60 + random.nextInt(240),
        totalReps: total,
        goodReps: good,
        averageScore: 60 + random.nextDouble() * 40, // 60~100점
        memo: day == 0 ? '오늘 기록' : null,
      ));
      sessionCount++;
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
