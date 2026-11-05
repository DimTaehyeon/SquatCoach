import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_profile.dart';
import 'profile_repository.dart';

/// 프로필을 이 기기(shared_preferences)에 저장합니다. 앱을 껐다 켜도 남아 있어요.
/// 로그인/서버가 없는 온디바이스 구조라서 이 기기의 프로필 1개만 다룹니다.
class LocalProfileRepository implements ProfileRepository {
  LocalProfileRepository(this._prefs);

  final SharedPreferences _prefs;
  static const _key = 'profile_v1';

  @override
  Future<UserProfile> loadProfile() async {
    final raw = _prefs.getString(_key);
    if (raw == null) return UserProfile();
    try {
      return UserProfile.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return UserProfile(); // 저장된 값이 깨졌으면 처음 상태로
    }
  }

  @override
  Future<void> saveProfile(UserProfile profile) async {
    await _prefs.setString(_key, jsonEncode(profile.toJson()));
  }
}
