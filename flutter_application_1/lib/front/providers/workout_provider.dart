import 'package:flutter/foundation.dart';

import '../models/workout_session.dart';
import '../repositories/workout_repository.dart';
import '../utils/calorie_series.dart';

/// 과거 운동 기록 / 통계 (홈, 기록, 마이페이지, 세션 상세 화면에서 사용).
class WorkoutProvider extends ChangeNotifier {
  WorkoutProvider(this._repository) {
    refresh();
  }

  final WorkoutRepository _repository;

  List<WorkoutSession> _sessions = [];
  List<DailyStat> _weeklyAccuracy = [];
  ActivitySummary _summary = ActivitySummary.empty;
  bool _isLoading = false;

  List<WorkoutSession> get sessions => _sessions;
  WorkoutSession? get latestSession => _sessions.isNotEmpty ? _sessions.first : null;
  List<DailyStat> get weeklyAccuracy => _weeklyAccuracy;
  ActivitySummary get summary => _summary;
  bool get isLoading => _isLoading;

  Future<void> refresh() async {
    _isLoading = true;
    notifyListeners();
    _sessions = await _repository.getRecentSessions();
    _weeklyAccuracy = await _repository.getWeeklyAccuracy();
    _summary = await _repository.getSummary();
    _isLoading = false;
    notifyListeners();
  }

  /// 세션 기록의 calories 를 기간별로 합산 (새 세션을 저장하고 refresh() 하면 바로 반영)
  CalorieReport calorieReport(CalorieRange range) => buildCalorieReport(_sessions, range);

  /// 모든 운동 기록 삭제 (마이페이지의 "로그아웃/초기화")
  Future<void> reset() async {
    await _repository.clearAll();
    await refresh();
  }

  Future<WorkoutSession> sessionById(String id) => _repository.getSessionById(id);
}
