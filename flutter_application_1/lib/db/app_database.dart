import 'package:path/path.dart';
import 'package:sqflite/sqflite.dart';

import '../models/user.dart';
import '../models/workout_session.dart';
import '../state/app_events.dart';

/// 폰 내부 SQLite DB. 앱 어디서든 AppDatabase.instance로 사용
///
/// 구조 (v2)
///   users             사용자
///   workout_sessions  운동 1번 (합계: 횟수·정확도·시간·칼로리·피드백 요약)
///   workout_sets      세트 (세션 1개에 여러 개)
///   rep_records       반복 1회 (세트 1개에 여러 개, 판정 검증용)
///   app_settings      설정 (알림 등) key-value
class AppDatabase {
  AppDatabase._();
  static final AppDatabase instance = AppDatabase._();

  static const _dbName = 'squat_coach.db';
  static const _dbVersion = 2;

  Database? _db;

  Future<Database> get database async => _db ??= await _open();

  Future<Database> _open() async {
    final path = join(await getDatabasesPath(), _dbName);
    return openDatabase(
      path,
      version: _dbVersion,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, version) async {
        await _createUsers(db);
        await _createSessions(db);
        await _createV2Tables(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _upgradeToV2(db);
      },
    );
  }

  static Future<void> _createUsers(Database db) => db.execute('''
    CREATE TABLE users (
      id          INTEGER PRIMARY KEY AUTOINCREMENT,
      name        TEXT    NOT NULL,
      age         INTEGER NOT NULL,
      height_cm   REAL    NOT NULL,
      weight_kg   REAL    NOT NULL,
      created_at  TEXT    NOT NULL
    )
  ''');

  static Future<void> _createSessions(Database db) async {
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
        calories_kcal  REAL    NOT NULL DEFAULT 0,
        FOREIGN KEY (user_id) REFERENCES users (id) ON DELETE CASCADE
      )
    ''');
    await db.execute(
        'CREATE INDEX idx_sessions_user ON workout_sessions (user_id)');
  }

  static Future<void> _createV2Tables(Database db) async {
    await db.execute('''
      CREATE TABLE workout_sets (
        id             INTEGER PRIMARY KEY AUTOINCREMENT,
        session_id     INTEGER NOT NULL,
        set_index      INTEGER NOT NULL,
        started_at     TEXT    NOT NULL,
        duration_sec   INTEGER NOT NULL,
        total_reps     INTEGER NOT NULL,
        good_reps      INTEGER NOT NULL,
        average_score  REAL    NOT NULL,
        fault_counts   TEXT,
        FOREIGN KEY (session_id) REFERENCES workout_sessions (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_sets_session ON workout_sets (session_id)');
    await db.execute('''
      CREATE TABLE rep_records (
        id         INTEGER PRIMARY KEY AUTOINCREMENT,
        set_id     INTEGER NOT NULL,
        rep_index  INTEGER NOT NULL,
        ended_at   TEXT    NOT NULL,
        is_good    INTEGER NOT NULL,
        faults     TEXT,
        warnings   TEXT,
        score      REAL    NOT NULL,
        ai_label   TEXT,
        FOREIGN KEY (set_id) REFERENCES workout_sets (id) ON DELETE CASCADE
      )
    ''');
    await db.execute('CREATE INDEX idx_reps_set ON rep_records (set_id)');
    await db.execute('''
      CREATE TABLE app_settings (
        key    TEXT PRIMARY KEY,
        value  TEXT
      )
    ''');
  }

  /// v1(세션 = 세트 1개)에서 v2로: 기존 기록은 "세트 1개짜리 세션"으로 옮김
  static Future<void> _upgradeToV2(Database db) async {
    await db.execute(
        'ALTER TABLE workout_sessions ADD COLUMN calories_kcal REAL NOT NULL DEFAULT 0');
    await _createV2Tables(db);
    await db.execute('''
      INSERT INTO workout_sets
        (session_id, set_index, started_at, duration_sec, total_reps, good_reps, average_score, fault_counts)
      SELECT id, 1, started_at, duration_sec, total_reps, good_reps, average_score, '{}'
      FROM workout_sessions
    ''');
  }

  // ---------------- User ----------------

  Future<int> insertUser(User user) async {
    final db = await database;
    return db.insert('users', user.toMap()..remove('id'));
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

  Future<void> updateUser(User user) async {
    final db = await database;
    await db.update('users', user.toMap()..remove('id'),
        where: 'id = ?', whereArgs: [user.id]);
    notifyDataChanged();
  }

  Future<int> deleteUser(int id) async {
    final db = await database;
    return db.delete('users', where: 'id = ?', whereArgs: [id]);
  }

  /// 기본 사용자 (첫 번째 사용자, 없으면 '나'를 만들어서)
  Future<User> getOrCreateDefaultUser() async {
    final users = await getAllUsers();
    if (users.isNotEmpty) return users.first;
    final user = User(
      name: '나',
      age: 25,
      heightCm: 170,
      weightKg: 65,
      createdAt: DateTime.now(),
    );
    final id = await insertUser(user);
    return user.copyWith(id: id);
  }

  // ---------------- 운동 저장 ----------------

  /// 세션 + 세트 + 반복을 한 번에 저장 (중간에 실패하면 전부 취소)
  Future<int> saveWorkout(WorkoutSession session) async {
    final db = await database;
    final id = await db.transaction((txn) async {
      final sessionId =
          await txn.insert('workout_sessions', session.toMap()..remove('id'));
      for (final set in session.sets) {
        final setId =
            await txn.insert('workout_sets', set.toMap(sessionId)..remove('id'));
        for (final rep in set.reps) {
          await txn.insert('rep_records', rep.toMap(setId)..remove('id'));
        }
      }
      return sessionId;
    });
    notifyDataChanged();
    return id;
  }

  Future<int> deleteSession(int id) async {
    final db = await database;
    final n = await db.delete('workout_sessions', where: 'id = ?', whereArgs: [id]);
    notifyDataChanged();
    return n;
  }

  // ---------------- 운동 조회 ----------------

  /// 특정 사용자의 세션 목록 (최신순, 세트 수만 같이 → 목록·그래프용)
  Future<List<WorkoutSession>> getSessionsByUser(int userId) async {
    final db = await database;
    final rows = await db.rawQuery('''
      SELECT s.*,
        (SELECT COUNT(*) FROM workout_sets w WHERE w.session_id = s.id) AS set_count
      FROM workout_sessions s
      WHERE s.user_id = ?
      ORDER BY s.started_at DESC
    ''', [userId]);
    return rows.map((r) => WorkoutSession.fromMap(r)).toList();
  }

  /// 세션 하나를 세트·반복까지 전부 불러옴 (상세 화면용)
  Future<WorkoutSession?> getSessionDetail(int sessionId) async {
    final db = await database;
    final rows = await db
        .query('workout_sessions', where: 'id = ?', whereArgs: [sessionId]);
    if (rows.isEmpty) return null;

    final setRows = await db.query('workout_sets',
        where: 'session_id = ?', whereArgs: [sessionId], orderBy: 'set_index');
    final sets = <WorkoutSet>[];
    for (final s in setRows) {
      final repRows = await db.query('rep_records',
          where: 'set_id = ?', whereArgs: [s['id']], orderBy: 'rep_index');
      sets.add(WorkoutSet.fromMap(s, reps: repRows.map(RepRecord.fromMap).toList()));
    }
    return WorkoutSession.fromMap(rows.first, sets: sets);
  }

  // ---------------- 설정 ----------------

  Future<String?> getSetting(String key) async {
    final db = await database;
    final rows =
        await db.query('app_settings', where: 'key = ?', whereArgs: [key]);
    return rows.isEmpty ? null : rows.first['value'] as String?;
  }

  Future<void> setSetting(String key, String? value) async {
    final db = await database;
    await db.insert('app_settings', {'key': key, 'value': value},
        conflictAlgorithm: ConflictAlgorithm.replace);
  }

  // ---------------- 테스트용 ----------------

  Future<(int users, int sessions, int sets, int reps)> counts() async {
    final db = await database;
    Future<int> count(String table) async =>
        Sqflite.firstIntValue(await db.rawQuery('SELECT COUNT(*) FROM $table')) ??
        0;
    return (
      await count('users'),
      await count('workout_sessions'),
      await count('workout_sets'),
      await count('rep_records'),
    );
  }

  /// 사용자·운동 기록 전부 삭제 (설정과 테이블 구조는 유지)
  Future<void> clearAll() async {
    final db = await database;
    await db.delete('rep_records');
    await db.delete('workout_sets');
    await db.delete('workout_sessions');
    await db.delete('users');
    notifyDataChanged();
  }
}
