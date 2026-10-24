import 'package:flutter/material.dart';

/// 마이페이지·통계 화면 색상
/// 차트 색과 상태 색은 어두운 배경(#1A1A19) 기준으로 대비를 검증한 값
class AppColors {
  AppColors._();

  // 배경과 카드
  static const surface = Color(0xFF1A1A19);
  static const card = Color(0xFF242422);
  static const cardBorder = Color(0xFF34342F);

  // 글자 (값·라벨은 항상 이 색을 씀. 차트 색으로 글자를 칠하지 않음)
  static const textPrimary = Color(0xFFF2F2F0);
  static const textSecondary = Color(0xFFB0B0AA);
  static const textMuted = Color(0xFF7C7C76);

  // 차트
  static const series = Color(0xFF3987E5); // 막대 색 (한 가지 지표 = 한 가지 색)
  static const seriesSoft = Color(0x333987E5); // 막대 색 20% (배경 강조용)
  static const grid = Color(0xFF2E2E2B);
  static const axis = Color(0xFF45453F);

  // 자세 점수 상태 (항상 아이콘 + 글자와 함께 표시)
  static const good = Color(0xFF0CA30C);
  static const warning = Color(0xFFFAB219);
  static const serious = Color(0xFFEC835A);
}

/// 자세 점수 등급
enum ScoreGrade { good, fair, poor }

extension ScoreGradeX on ScoreGrade {
  static ScoreGrade of(double score) => score >= 85
      ? ScoreGrade.good
      : score >= 70
          ? ScoreGrade.fair
          : ScoreGrade.poor;

  String get label => switch (this) {
        ScoreGrade.good => '좋음',
        ScoreGrade.fair => '보통',
        ScoreGrade.poor => '개선 필요',
      };

  Color get color => switch (this) {
        ScoreGrade.good => AppColors.good,
        ScoreGrade.fair => AppColors.warning,
        ScoreGrade.poor => AppColors.serious,
      };

  IconData get icon => switch (this) {
        ScoreGrade.good => Icons.check_circle,
        ScoreGrade.fair => Icons.remove_circle,
        ScoreGrade.poor => Icons.error,
      };
}
