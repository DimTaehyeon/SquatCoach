/// 소모 칼로리 계산
///
/// kcal = MET × 체중(kg) × 운동 시간(시간)
/// - 맨몸 스쿼트 MET 5.0 (Compendium of Physical Activities의 맨몸 근력운동 중간 강도 수준)
/// - 운동 시간은 세트를 실제로 한 시간만 더함 (세트 사이 휴식 제외)
///
/// ✏️ 기획팀이 다른 계산식을 원하면 이 파일만 바꾸면 됩니다.
library;

const squatMet = 5.0;

double caloriesKcal({required double weightKg, required int activeSeconds}) {
  return squatMet * weightKg * activeSeconds / 3600;
}
