import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 앱 전체에서 쓰는 버튼. 누르면 살짝 눌리는 애니메이션이 들어가 있습니다.
/// - 기본: 초록 채움 버튼
/// - [color]: 채움 색 변경 (예: 빨간 "세트 종료")
/// - [filled] = false: 흰 배경 + 테두리 버튼 (예: "이번 세트 다시 하기")
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.filled = true,
    this.color,
    this.icon,
    this.height = 52,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool filled;
  final Color? color;
  final IconData? icon;
  final double height;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  double _scale = 1.0;

  void _setPressed(bool pressed) => setState(() => _scale = pressed ? 0.97 : 1.0);

  @override
  Widget build(BuildContext context) {
    final disabled = widget.onPressed == null || widget.isLoading;
    final fillColor = widget.color ?? AppColors.primary;
    final textColor = widget.filled ? Colors.white : AppColors.textDark;

    final child = Container(
      height: widget.height,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.button),
        color: widget.filled ? (disabled ? fillColor.withOpacity(0.4) : fillColor) : Colors.white,
        border: widget.filled ? null : Border.all(color: AppColors.cardBorder, width: 1.2),
      ),
      child: widget.isLoading
          ? const SizedBox(
              width: 22,
              height: 22,
              child: CircularProgressIndicator(strokeWidth: 2.4, color: Colors.white),
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (widget.icon != null) ...[
                  Icon(widget.icon, size: 16, color: textColor),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700, color: textColor),
                ),
              ],
            ),
    );

    return GestureDetector(
      onTapDown: disabled ? null : (_) => _setPressed(true),
      onTapUp: disabled ? null : (_) => _setPressed(false),
      onTapCancel: disabled ? null : () => _setPressed(false),
      onTap: disabled ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _scale,
        duration: const Duration(milliseconds: 100),
        child: child,
      ),
    );
  }
}
