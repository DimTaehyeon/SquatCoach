import 'dart:convert';
import 'dart:typed_data';

enum Gender { male, female }

extension GenderLabel on Gender {
  String get label => this == Gender.male ? '남' : '여';
}

enum FitnessGoal { postureCorrection, strength, rehab }

extension FitnessGoalLabel on FitnessGoal {
  String get title {
    switch (this) {
      case FitnessGoal.postureCorrection:
        return '자세 교정';
      case FitnessGoal.strength:
        return '하체 근력 강화';
      case FitnessGoal.rehab:
        return '재활 / 통증 완화';
    }
  }

  String get subtitle {
    switch (this) {
      case FitnessGoal.postureCorrection:
        return '정확한 스쿼트 자세를 배우고 싶어요';
      case FitnessGoal.strength:
        return '꾸준한 반복으로 근력을 키우고 싶어요';
      case FitnessGoal.rehab:
        return '무릎·허리 부담을 줄이며 운동하고 싶어요';
    }
  }
}

/// 이 기기의 사용자 프로필. 로그인이 없는 온디바이스 구조라 계정 없이 하나만 존재합니다.
/// 기기 안에는 LocalProfileRepository(shared_preferences)로 저장됩니다.
class UserProfile {
  String name;
  Gender? gender;
  FitnessGoal? goal;
  int heightCm;
  int weightKg;
  int targetRepsPerSet;
  bool notificationsEnabled;
  bool voiceEnabled; // 자세 오류 음성 안내(TTS)
  bool soundEnabled; // 자세 오류 경고음
  int reminderHour; // 매일 운동 알림 시각
  int reminderMinute;
  bool onboarded; // 프로필~사용법 안내까지 끝냈는지 (다음 실행 때 바로 홈으로 가기 위해)
  Uint8List? photoBytes; // 갤러리에서 고른 프로필 사진 (없으면 이름 첫 글자 표시)

  UserProfile({
    this.name = '',
    this.gender,
    this.goal,
    this.heightCm = 174,
    this.weightKg = 68,
    this.targetRepsPerSet = 12,
    this.notificationsEnabled = false,
    this.voiceEnabled = true,
    this.soundEnabled = true,
    this.reminderHour = 20,
    this.reminderMinute = 0,
    this.onboarded = false,
    this.photoBytes,
  });

  String get initial => name.isNotEmpty ? name.substring(0, 1) : '?';

  /// 기기 저장소(shared_preferences)에 넣기 위한 JSON 변환
  Map<String, dynamic> toJson() => {
        'name': name,
        'gender': gender?.name,
        'goal': goal?.name,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'targetRepsPerSet': targetRepsPerSet,
        'notificationsEnabled': notificationsEnabled,
        'voiceEnabled': voiceEnabled,
        'soundEnabled': soundEnabled,
        'reminderHour': reminderHour,
        'reminderMinute': reminderMinute,
        'onboarded': onboarded,
        'photo': photoBytes == null ? null : base64Encode(photoBytes!),
      };

  factory UserProfile.fromJson(Map<String, dynamic> j) {
    T? byName<T extends Enum>(List<T> values, Object? name) {
      for (final v in values) {
        if (v.name == name) return v;
      }
      return null;
    }

    final photo = j['photo'];
    return UserProfile(
      name: (j['name'] as String?) ?? '',
      gender: byName(Gender.values, j['gender']),
      goal: byName(FitnessGoal.values, j['goal']),
      heightCm: (j['heightCm'] as num?)?.toInt() ?? 174,
      weightKg: (j['weightKg'] as num?)?.toInt() ?? 68,
      targetRepsPerSet: (j['targetRepsPerSet'] as num?)?.toInt() ?? 12,
      notificationsEnabled: (j['notificationsEnabled'] as bool?) ?? false,
      voiceEnabled: (j['voiceEnabled'] as bool?) ?? true,
      soundEnabled: (j['soundEnabled'] as bool?) ?? true,
      reminderHour: (j['reminderHour'] as num?)?.toInt() ?? 20,
      reminderMinute: (j['reminderMinute'] as num?)?.toInt() ?? 0,
      onboarded: (j['onboarded'] as bool?) ?? false,
      photoBytes: photo is String && photo.isNotEmpty ? base64Decode(photo) : null,
    );
  }
}
