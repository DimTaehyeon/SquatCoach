import 'package:flutter/material.dart';

import 'pages/home_page.dart';
import 'pages/my_page.dart';
import 'pages/workout_start_page.dart';
import 'ui/app_colors.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const SquatCoachApp());
}

class SquatCoachApp extends StatelessWidget {
  const SquatCoachApp({super.key});

  @override
  Widget build(BuildContext context) {
    final base = ThemeData.dark(useMaterial3: true);
    return MaterialApp(
      title: 'SquatCoach',
      debugShowCheckedModeBanner: false,
      theme: base.copyWith(
        scaffoldBackgroundColor: AppColors.surface,
        colorScheme: base.colorScheme.copyWith(
          primary: AppColors.series,
          surface: AppColors.surface,
        ),
        navigationBarTheme: const NavigationBarThemeData(
          backgroundColor: AppColors.card,
          indicatorColor: AppColors.seriesSoft,
        ),
      ),
      home: const RootTabs(),
    );
  }
}

/// 하단 탭: 홈(기록) / 운동 / 마이페이지
class RootTabs extends StatefulWidget {
  const RootTabs({super.key});

  @override
  State<RootTabs> createState() => _RootTabsState();
}

class _RootTabsState extends State<RootTabs> {
  int _index = 0;

  static const _pages = [HomePage(), WorkoutStartPage(), MyPage()];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _index, children: _pages),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(
              icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: '홈'),
          NavigationDestination(
              icon: Icon(Icons.fitness_center_outlined),
              selectedIcon: Icon(Icons.fitness_center),
              label: '운동'),
          NavigationDestination(
              icon: Icon(Icons.person_outline), selectedIcon: Icon(Icons.person), label: '마이페이지'),
        ],
      ),
    );
  }
}
