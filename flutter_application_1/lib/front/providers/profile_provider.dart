import 'dart:typed_data';

import 'package:flutter/foundation.dart';

import '../../services/notification_service.dart';
import '../models/user_profile.dart';
import '../repositories/profile_repository.dart';

/// 이 기기의 사용자 프로필을 앱 전체에 공유하는 Provider (로그인 없음).
class ProfileProvider extends ChangeNotifier {
  ProfileProvider(this._repository) {
    ready = _load();
  }

  /// 저장된 프로필을 다 불러왔을 때 끝나는 Future (스플래시에서 기다립니다)
  late final Future<void> ready;

  final ProfileRepository _repository;

  UserProfile _user = UserProfile();
  UserProfile get user => _user;

  Future<void> _load() async {
    try {
      _user = await _repository.loadProfile();
    } catch (_) {
      _user = UserProfile(); // 저장된 값이 깨졌으면 처음 상태로 시작
    }
    notifyListeners();
  }

  Future<void> setGoal(FitnessGoal goal) async {
    _user.goal = goal;
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  /// 프로필 입력~사용법 안내까지 끝났을 때 호출 → 다음 실행부터는 바로 홈으로 갑니다.
  Future<void> markOnboarded() async {
    if (_user.onboarded) return;
    _user.onboarded = true;
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  Future<void> setVoice(bool enabled) async {
    _user.voiceEnabled = enabled;
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  Future<void> setSound(bool enabled) async {
    _user.soundEnabled = enabled;
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  /// 매일 운동 알림 켜기/끄기 (실제 알림 예약은 NotificationService가 합니다)
  /// 켜려는데 알림 권한이 거절되면 false 를 돌려주고 꺼 둡니다.
  Future<bool> setNotifications(bool enabled) async {
    final service = NotificationService.instance;
    var on = enabled;
    try {
      if (enabled) {
        on = await service.requestPermission();
        if (on) await service.scheduleDaily(_user.reminderHour, _user.reminderMinute);
      } else {
        await service.cancelDaily();
      }
    } catch (e) {
      debugPrint('알림 설정 실패: $e');
      on = false;
    }
    _user.notificationsEnabled = on;
    await _repository.saveProfile(_user);
    notifyListeners();
    return on == enabled;
  }

  /// 알림 시각 변경 (켜져 있으면 다시 예약)
  Future<void> setReminderTime(int hour, int minute) async {
    _user.reminderHour = hour;
    _user.reminderMinute = minute;
    if (_user.notificationsEnabled) {
      try {
        await NotificationService.instance.scheduleDaily(hour, minute);
      } catch (e) {
        debugPrint('알림 예약 실패: $e');
      }
    }
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  Future<void> updateProfile({
    String? name,
    Gender? gender,
    int? heightCm,
    int? weightKg,
    int? targetRepsPerSet,
  }) async {
    if (name != null) _user.name = name;
    if (gender != null) _user.gender = gender;
    if (heightCm != null) _user.heightCm = heightCm;
    if (weightKg != null) _user.weightKg = weightKg;
    if (targetRepsPerSet != null) _user.targetRepsPerSet = targetRepsPerSet;
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  Future<void> setPhoto(Uint8List? bytes) async {
    _user.photoBytes = bytes;
    await _repository.saveProfile(_user);
    notifyListeners();
  }

  /// 프로필을 처음 상태로 되돌립니다. (마이페이지의 "로그아웃" 항목에서 사용)
  Future<void> reset() async {
    try {
      await NotificationService.instance.cancelDaily();
    } catch (_) {}
    _user = UserProfile();
    await _repository.saveProfile(_user);
    notifyListeners();
  }
}
