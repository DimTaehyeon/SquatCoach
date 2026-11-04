/// 스쿼트 자세오류 판정 기준
///
/// 출처: "SquatCoach — 스쿼트 자세오류 판정 기준" v0.2 (기획 김민준, 2026-10-02)
/// 전제: 맨몸 스쿼트 · 정면 카메라 1대
///
/// ✏️ 기획팀이 자체 촬영 후 수치를 바꿀 때는 이 파일의 숫자만 고치면 됩니다.
library;

/// 주의 / 오류 두 단계 기준값
class Threshold {
  const Threshold(this.warning, this.error);
  final double warning;
  final double error;
}

/// 판정 결과 단계
enum Level { ok, warning, error }

/// 구분: 판정 대상(정상/오류 판정 + 피드백) / 참고(화면 표시만) / 기록만(사용자에게 안 보임)
enum CheckRole { judged, reference, recordOnly }

/// 오류 항목
enum SquatFault {
  kneeCaving('다리 모아짐', CheckRole.judged, '무릎이 안으로 모이지 않게 바깥으로 밀어 주세요'),
  shallowDepth('무릎 덜 굽힘', CheckRole.judged, '조금 더 깊이 앉아 주세요'),
  lateralTilt('몸이 좌우로 기울어짐', CheckRole.judged, '양쪽 다리에 체중을 고르게 실어 주세요'),
  forwardLean('몸이 앞으로 기울어짐', CheckRole.reference, '가슴을 펴고 상체를 세워 주세요'),
  heelRaise('발뒤꿈치 들림', CheckRole.reference, '뒤꿈치를 바닥에 붙여 주세요'),
  stanceWidth('다리 벌어짐', CheckRole.reference, '발을 어깨너비 정도로 벌려 주세요');

  const SquatFault(this.label, this.role, this.feedback);
  final String label;
  final CheckRole role;
  final String feedback;
}

// ───────────────────────── 1. 하체 오류 ─────────────────────────

/// 다리 모아짐: 무릎 간격 ÷ 발목 간격 (작을수록 모임) · 내려가기~올라오기 전체 · 판정 대상
const kneeCavingRatio = Threshold(1.0, 0.8);

/// 무릎 덜 굽힘: 엉덩이가 내려간 높이 ÷ 서 있을 때 허벅지 길이 (작을수록 얕음) · 최저점 · 판정 대상
const depthRatio = Threshold(0.75, 0.60);

/// 다리 벌어짐(보폭): 발목 간격 ÷ 어깨 너비 · 서 있는 준비 자세 · 참고
const stanceTooWide = Threshold(1.6, 1.8);
const stanceTooNarrow = Threshold(0.9, 0.8);

/// 발뒤꿈치 들림: 뒤꿈치가 올라간 높이 ÷ 서 있을 때 정강이 길이 · 최저점 · 참고
const heelRaiseRatio = Threshold(0.04, 0.07);

// 발끝 벌어짐(발끝 방향 각도 >35°/45°)과 발목 회내(>0.08, 기록만)는
// 정면 2D 좌표로는 안정적으로 잴 수 없어 아직 구현하지 않았습니다.

// ───────────────────────── 2. 상체 오류 ─────────────────────────

/// 몸이 좌우로 기울어짐 (3개 지표 중 하나라도 넘으면 해당) · 최저점 · 판정 대상
const shoulderTiltDeg = Threshold(5, 10); // 어깨선이 서 있을 때보다 더 기운 각도(°)
const pelvisTiltRatio = Threshold(0.08, 0.15); // 골반 좌우 높이 차(서 있을 때 대비) ÷ 서 있을 때 허벅지 길이
const pelvisShiftRatio = Threshold(0.10, 0.20); // 골반 중심 옆 이동 ÷ 서 있을 때 발목 간격

/// 몸이 앞으로 기울어짐: 최저점 상체 세로 길이 ÷ 서 있을 때 상체 길이 (작을수록 숙임) · 참고
const forwardLeanRatio = Threshold(0.65, 0.55);

// ───────────────────────── 3. 판정 규칙 ─────────────────────────

/// [일반 모드] 연속 이 프레임 수 이상 기준을 넘어야 오류로 인정
const consecutiveFrames = 3;

/// 깊이: 이 프레임 수 이상 유지한 깊이를 앉은 깊이로 봄 (두 모드 공통)
/// ⚠️ 자세 오류 지속 시간과 따로 둠. 늘리면 오히려 깊이가 얕게 계산돼 오류가 늘어남
const depthSustainFrames = 3;

// ───────────────────────── 4. 판정 모드 (초보자 / 일반) ─────────────────────────

/// DB 설정에 판정 모드를 저장하는 이름
const kJudgeModeKey = 'judge_mode';

/// 판정 모드
enum JudgeMode {
  beginner('초보자', '스쿼트를 처음 시작하는 분께 맞춘 기준이에요'),
  standard('일반', '스쿼트에 익숙한 분을 위한 정확한 자세 기준이에요');

  const JudgeMode(this.label, this.description);
  final String label;
  final String description;

  /// DB에 저장된 이름 → 모드 (없거나 모르는 값이면 초보자)
  static JudgeMode fromName(String? name) =>
      JudgeMode.values.firstWhere((m) => m.name == name, orElse: () => JudgeMode.beginner);
}

/// 모드에 따라 달라지는 기준값. 여기 없는 항목(참고 항목, 보폭 등)은 두 모드 공통
class JudgeCriteria {
  const JudgeCriteria({
    required this.kneeCaving,
    required this.depth,
    required this.shoulderTilt,
    required this.pelvisTilt,
    required this.pelvisShift,
    this.sustainFrames,
    this.sustainDuration,
  });

  final Threshold kneeCaving; // 다리 모아짐 (작을수록 나쁨)
  final Threshold depth; // 무릎 덜 굽힘 (작을수록 나쁨)
  final Threshold shoulderTilt; // 어깨 기울기(°) (클수록 나쁨)
  final Threshold pelvisTilt; // 골반 좌우 높이 차 (클수록 나쁨)
  final Threshold pelvisShift; // 골반 좌우 밀림 (클수록 나쁨)

  /// 자세 오류 인정 조건: [sustainDuration]이 있으면 그 시간 이상 지속,
  /// 없으면 연속 [sustainFrames]프레임 이상 (폰 속도에 따라 시간이 달라짐)
  final int? sustainFrames;
  final Duration? sustainDuration;

  bool isSustained(int frames, Duration span) => sustainDuration != null
      ? span >= sustainDuration!
      : frames >= (sustainFrames ?? consecutiveFrames);

  /// 일반 모드: 기획 판정 기준 v0.2 그대로
  static const standard = JudgeCriteria(
    kneeCaving: kneeCavingRatio,
    depth: depthRatio,
    shoulderTilt: shoulderTiltDeg,
    pelvisTilt: pelvisTiltRatio,
    pelvisShift: pelvisShiftRatio,
    sustainFrames: consecutiveFrames,
  );

  /// 초보자 모드: 초보자용 판정 기준표 (강현욱 2026-11-04)
  static const beginner = JudgeCriteria(
    kneeCaving: Threshold(0.90, 0.75),
    depth: Threshold(0.65, 0.50),
    shoulderTilt: Threshold(6, 10),
    pelvisTilt: Threshold(0.10, 0.18),
    pelvisShift: Threshold(0.12, 0.22),
    sustainDuration: Duration(milliseconds: 300), // 0.3초 이상 지속돼야 오류
  );

  static JudgeCriteria of(JudgeMode mode) => switch (mode) {
        JudgeMode.beginner => beginner,
        JudgeMode.standard => standard,
      };
}

/// 관절 인식률이 이 값 미만인 프레임은 판정에서 제외
const minVisibility = 0.5;

/// "서 있을 때 값"을 재는 시간
const calibrationDuration = Duration(seconds: 2);

// ───────────────────────── 반복 구분 (팀 초기값) ─────────────────────────

/// 1회 구분: 엉덩이가 직전에 서 있던 높이보다 [repDownRatio] × 허벅지 길이 이상 내려가면 '앉는 중',
/// 내려간 만큼의 [repReturnFraction] 이내로 다시 올라오면 1회 완료.
/// (반복 사이에 완전히 일어서지 않아도 셀 수 있게 직전 높이를 기준으로 함)
const repDownRatio = 0.25;
const repReturnFraction = 0.35;

/// 중복 카운트 방지
/// - 엉덩이 높이는 최근 [repSmoothFrames]프레임의 중앙값으로 판단 (관절 떨림 무시)
/// - 다 올라온 상태가 [repReturnFrames]프레임 연속이어야 1회 완료
/// - 앉기 시작~완료가 [minRepDuration]보다 짧으면 세지 않음
const repSmoothFrames = 5;
const repReturnFrames = 3;
const minRepDuration = Duration(milliseconds: 600);

/// 영점 자동 재조정 (세트 중에 사용자가 앞뒤·옆으로 자리를 옮겨도 계속 세기 위해)
/// - [rebaselineStillTime] 동안 가만히 서 있고(엉덩이 흔들림 < [rebaselineStillRatio] × 허벅지),
/// - 영점 때와 서 있는 높이·크기·좌우 위치가 아래 값 이상 달라졌으면 그 자리에서 영점을 다시 잡음
const rebaselineStillTime = Duration(seconds: 1);
const rebaselineStillRatio = 0.06;
const rebaselineHeightDiff = 0.08; // 서 있는 엉덩이 높이 차 ÷ 허벅지
const rebaselineScaleDiff = 0.10; // 허벅지 길이(= 카메라와의 거리) 변화 비율
const rebaselineSideDiff = 0.15; // 좌우 이동 ÷ 발목 간격

/// 1회 시작 판단용 '서 있는 높이'는 최근 이 시간 안의 가장 높은 자세로 봄
const standingWindow = Duration(milliseconds: 1500);

/// 걷기는 1회로 세지 않음: 앉았다 일어서는 동안
/// - 발(양 발목 가운데)이 [walkFootMove] × 허벅지 길이 이상 움직였거나
/// - 몸 크기(어깨 폭)가 [walkScaleChange]배 이상 바뀌었으면(카메라 쪽으로 다가오거나 멀어짐) 걷는 중으로 봄
/// 시연 영상 측정: 실제 스쿼트는 발 이동 0.04~0.17, 크기 변화 1.04~1.15배 / 걷기는 0.52 이상, 1.62배 이상
const walkFootMove = 0.35;
const walkScaleChange = 1.35;

/// 정면 확인: 어깨 너비가 허벅지 길이의 이 비율보다 작으면 옆으로 선 것으로 봄
const minFrontalShoulderToThigh = 0.6;
