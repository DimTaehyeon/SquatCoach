import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'front/providers/profile_provider.dart';
import 'front/providers/session_provider.dart';
import 'front/providers/workout_provider.dart';
import 'front/repositories/db_workout_repository.dart';
import 'front/repositories/local_profile_repository.dart';
import 'front/repositories/profile_repository.dart';
import 'front/repositories/workout_repository.dart';
import 'front/screens/analysis_screen.dart';
import 'front/screens/calorie_activity_screen.dart';
import 'front/screens/camera_setup_screen.dart';
import 'front/screens/countdown_screen.dart';
import 'front/screens/goal_screen.dart';
import 'front/screens/guide_screen.dart';
import 'front/screens/home/home_shell.dart';
import 'front/screens/paused_screen.dart';
import 'front/screens/permission_request_screen.dart';
import 'front/screens/profile_screen.dart';
import 'front/screens/recognition_fail_screen.dart';
import 'front/screens/rest_between_sets_screen.dart';
import 'front/screens/result_screen.dart';
import 'front/screens/session_detail_screen.dart';
import 'front/screens/splash_screen.dart';
import 'front/theme/app_theme.dart';
import 'front/widgets/bottom_nav_bar.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final prefs = await SharedPreferences.getInstance();
  runApp(SquatCoachApp(prefs: prefs));
}

/// 앱 화면 흐름
///
/// [온보딩] /splash → /profile → /goal → /permission → /guide → /main   (첫 실행만, 이후엔 /splash → /main)
/// [운동]   /main(운동 탭: 운동 설정·판정 모드) → /camera-setup → /countdown(3-2-1) → /analysis(+ 세트 사이 /countdown, 못 찾으면 /recognition-fail)
///          (영점 조절 → 세트 진행 ⇄ /paused) → (세트 끝) /rest → /countdown → 영점 조절 ... → /result → /main
/// [기록]   /main(기록 탭) → /session-detail
/// [마이]   /main(마이 탭) → /profile-edit, /calories(칼로리 활동)
///
/// 데이터: 운동 기록은 백엔드의 SQLite(AppDatabase), 프로필은 shared_preferences 에 기기 안에만 저장합니다.
/// 화면(lib/front)은 Provider 로 데이터를 받고, 자세 인식·판정·횟수 세기는 lib/ai, lib/workout 이 맡습니다.
class SquatCoachApp extends StatelessWidget {
  const SquatCoachApp({super.key, required this.prefs});

  final SharedPreferences prefs;

  @override
  Widget build(BuildContext context) {
    final ProfileRepository profileRepository = LocalProfileRepository(prefs);
    final WorkoutRepository workoutRepository = DbWorkoutRepository();

    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ProfileProvider(profileRepository)),
        ChangeNotifierProvider(create: (_) => WorkoutProvider(workoutRepository)),
        ChangeNotifierProvider(create: (_) => SessionProvider()),
      ],
      child: MaterialApp(
        title: 'Squat Coach',
        debugShowCheckedModeBanner: false,
        theme: buildAppTheme(),
        initialRoute: '/splash',
        routes: {
          '/splash': (_) => const SplashScreen(),
          '/profile': (_) => const ProfileScreen(firstRun: true),
          '/profile-edit': (_) => const ProfileScreen(),
          '/calories': (_) => const CalorieActivityScreen(),
          '/goal': (_) => const GoalScreen(),
          '/permission': (_) => const PermissionRequestScreen(),
          '/permission-again': (_) => const PermissionRequestScreen(fromOnboarding: false),
          '/guide': (_) => const GuideScreen(),
          '/camera-setup': (_) => const CameraSetupScreen(),
          '/recognition-fail': (_) => const RecognitionFailScreen(),
          '/countdown': (_) => const CountdownScreen(),
          '/analysis': (_) => const AnalysisScreen(),
          '/paused': (_) => const PausedScreen(),
          '/rest': (_) => const RestBetweenSetsScreen(),
          '/result': (_) => const ResultScreen(),
        },
        onGenerateRoute: (settings) {
          switch (settings.name) {
            case '/main':
              final tab = settings.arguments is AppTab ? settings.arguments as AppTab : AppTab.home;
              return MaterialPageRoute(builder: (_) => HomeShell(initialTab: tab), settings: settings);
            case '/session-detail':
              final sessionId = settings.arguments as String;
              return MaterialPageRoute(builder: (_) => SessionDetailScreen(sessionId: sessionId), settings: settings);
          }
          return null;
        },
      ),
    );
  }
}
