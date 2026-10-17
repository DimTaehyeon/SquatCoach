import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../models/workout_session.dart';

/// 폰 내부 SQLite DB. 앱 어디서든 AppDatabase.instance로 사용
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'squat_coach.db';
  static const _dbVersion = 1; // 테이블 구조를 바꾸면 올리고 onUpgrade 작성

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      // 외래키(user_id → users.id) 규칙을 켜기
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE users (
            id          INTEGER PRIMARY KEY AUTOINCREMENT,
            name        TEXT    NOT NULL,
            age         INTEGER NOT NULL,
            height_cm   REAL    NOT NULL,
            weight_kg   REAL    NOT NULL,
            created_at  TEXT    NOT NULL
          )
        ''');
        await db.execute('''
          CREATE TABLE workout_sessions (
            id             INTEGER PRIMARY KEY AUTOINCREMENT,
            user_id        INTEGER NOT NULL,
            exercise_type  TEXT    NOT NULL,
            started_at     TEXT    NOT NULL,
            duration_sec   INTEGER NOT NULL,
            total_reps     INTEGER NOT NULL,
            good_reps      INTEGER NOT NULL,
            average_score  REAL    NOT NULL,
            memo           TEXT,
            FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
          )
        ''');
        await db.execute(
            'CREATE INDEX idx_sessions_user ON workout_sessions (user_id)');
      },
    );
  }

  // ---------------- User ----------------

  /// 저장하고 DB가 붙여준 id를 돌려줌
  Future<int> insertUser(User user) async {
    final db = await database;
    final map = user.toMap()..remove('id');
    return db.insert('users', map);
  }

  Future<User?> getUser(int id) async {
    final db = await database;
    final rows = await db.query('users', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : User.fromMap(rows.first);
  }

  Future<List<User>> getAllUsers() async {
    final db = await database;
    final rows = await db.query('users', orderBy: 'id');
    return rows.map(User.fromMap).toList();
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  // ---------------- WorkoutSession ----------------

  Future<int> insertSession(WorkoutSession session) async {
    final db = await database;
    final map = session.toMap()..remove('id');
    return db.insert('workout_sessions', map);
  }

  /// 특정 사용자의 운동 기록 (최신순)
  Future<List<WorkoutSession>> getSessionsByUser(int userId) async {
    final db = await database;
    final rows = await db.query(
      'workout_sessions',
      where: 'user_id = ?',
      whereArgs: [userId],
      orderBy: 'started_at DESC',
    );
    return rows.map(WorkoutSession.fromMap).toList();
  }

  Future<List<WorkoutSession>> getAllSessions() async {
    final db = await database;
    final rows =
        await db.query('workout_sessions', orderBy: 'started_at DESC');
    return rows.map(WorkoutSession.fromMap).toList();
  }

  // ---------------- 테스트용 ----------------

  Future<(int users, int sessions)> counts() async {
    final db = await database;
    final u = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM users')) ??
        0;
    final s = Sqflite.firstIntValue(
            await db.rawQuery('SELECT COUNT(*) FROM workout_sessions')) ??
        0;
    return (u, s);
  }

  /// 모든 데이터 삭제 (테이블 구조는 유지)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('workout_sessions');
    await db.delete('users');
  }
}
