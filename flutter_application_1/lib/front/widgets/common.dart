import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 흰색 둥근 사각형 아이콘 버튼 (뒤로가기, 설정, 필터, 공유 등)
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 40,
    this.background,
    this.iconColor,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final Color? background;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: background ?? Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.cardBorder),
        ),
        child: Icon(icon, size: 20, color: iconColor ?? AppColors.textDark),
      ),
    );
  }
}

/// 상단 헤더: 왼쪽 뒤로가기 / 가운데 제목 / 오른쪽 trailing
class ScreenHeader extends StatelessWidget {
  const ScreenHeader({super.key, required this.title, this.onBack, this.trailing, this.titleColor});

  final String title;
  final VoidCallback? onBack;
  final Widget? trailing;
  final Color? titleColor;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: titleColor ?? AppColors.textDark)),
          if (onBack != null)
            Align(
              alignment: Alignment.centerLeft,
              child: RoundIconButton(icon: Icons.chevron_left_rounded, onTap: onBack),
            ),
          if (trailing != null) Align(alignment: Alignment.centerRight, child: trailing),
        ],
      ),
    );
  }
}

/// 흰 배경 + 얇은 테두리 카드
class SoftCard extends StatelessWidget {
  const SoftCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.color = Colors.white,
    this.radius = AppRadius.card,
    this.onTap,
  });

  final Widget child;
  final EdgeInsets padding;
  final Color color;
  final double radius;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: double.infinity,
      padding: padding,
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: child,
    );
    if (onTap == null) return box;
    return GestureDetector(onTap: onTap, behavior: HitTestBehavior.opaque, child: box);
  }
}

/// 숫자 + 단위 + 라벨로 이루어진 작은 통계 카드 (예: 83% 현재 정확도)
class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.value, required this.label, this.unit, this.valueColor});

  final String value;
  final String? unit;
  final String label;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.cardBorder),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          RichText(
            text: TextSpan(
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: valueColor ?? AppColors.textDark),
              children: [
                TextSpan(text: value),
                if (unit != null) TextSpan(text: unit, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
        ],
      ),
    );
  }
}

/// 카드 안의 둥근 아이콘 타일
class IconTile extends StatelessWidget {
  const IconTile({super.key, required this.icon, this.size = 40, this.background, this.iconColor});

  final IconData icon;
  final double size;
  final Color? background;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: background ?? AppColors.primarySoft,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Icon(icon, size: size * 0.5, color: iconColor ?? AppColors.primary),
    );
  }
}
