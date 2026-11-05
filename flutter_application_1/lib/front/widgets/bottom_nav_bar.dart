import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// 하단 탭: 홈 / 운동 / 기록 / 마이 (Figma 순서)
enum AppTab { home, workout, records, my }

class BottomNavBar extends StatelessWidget {
  const BottomNavBar({super.key, required this.current, required this.onTap});

  final AppTab current;
  final ValueChanged<AppTab> onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.only(top: 8, bottom: 4),
      decoration: const BoxDecoration(
        color: AppColors.background,
        border: Border(top: BorderSide(color: AppColors.cardBorder)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            _item(Icons.home_outlined, Icons.home_rounded, '홈', AppTab.home),
            _item(Icons.accessibility_new_rounded, Icons.accessibility_new_rounded, '운동', AppTab.workout),
            _item(Icons.bar_chart_rounded, Icons.bar_chart_rounded, '기록', AppTab.records),
            _item(Icons.person_outline_rounded, Icons.person_rounded, '마이', AppTab.my),
          ],
        ),
      ),
    );
  }

  Widget _item(IconData icon, IconData selectedIcon, String label, AppTab tab) {
    final selected = tab == current;
    final color = selected ? AppColors.primary : AppColors.textFaint;
    return Expanded(
      child: InkWell(
        onTap: () => onTap(tab),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(selected ? selectedIcon : icon, color: color, size: 24),
              const SizedBox(height: 2),
              Text(
                label,
                style: TextStyle(fontSize: 10.5, color: color, fontWeight: selected ? FontWeight.w700 : FontWeight.w500),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
