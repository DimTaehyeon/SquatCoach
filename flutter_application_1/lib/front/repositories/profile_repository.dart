import '../models/user_profile.dart';

/// 사용자 프로필(이름, 목표, 키, 체중 등)을 저장/불러오는 인터페이스.
/// 로그인이 없는 온디바이스 구조라 계정 개념 없이 "이 기기의 프로필" 하나만 다룹니다.
/// 지금은 메모리 Mock이고, 앱을 껐다 켜도 남기려면 shared_preferences 같은
/// 로컬 저장소 구현체(LocalProfileRepository)를 추가해서 main.dart에서 교체하세요.
abstract class ProfileRepository {
  Future<UserProfile> loadProfile();
  Future<void> saveProfile(UserProfile profile);
}
