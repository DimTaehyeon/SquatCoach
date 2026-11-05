import 'package:flutter/material.dart';

import '../../widgets/bottom_nav_bar.dart';
import 'main_tab.dart';
import 'my_page_tab.dart';
import 'records_tab.dart';
import 'workout_setup_tab.dart';

/// 홈 / 운동 / 기록 / 마이 네 화면을 하단 네비게이션으로 묶어주는 쉘.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, this.initialTab = AppTab.home});

  final AppTab initialTab;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  late AppTab _tab = widget.initialTab;

  void _go(AppTab tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          index: AppTab.values.indexOf(_tab),
          children: [
            MainTab(onGoTab: _go),
            WorkoutSetupTab(onBack: () => _go(AppTab.home)),
            RecordsTab(onBack: () => _go(AppTab.home)),
            MyPageTab(onBack: () => _go(AppTab.home)),
          ],
        ),
      ),
      bottomNavigationBar: BottomNavBar(current: _tab, onTap: _go),
    );
  }
}
