import 'package:flutter/material.dart';

import 'db_test_page.dart';
import 'pages/ai_coach_page.dart';
import 'pages/my_page.dart';
import 'pose_camera_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoseApp());
}

class PoseApp extends StatelessWidget {
  const PoseApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Squat Coach',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const HomePage(),
    );
  }
}

/// 개발 중 기능별 테스트 화면으로 들어가는 메뉴
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Squat Coach (개발용)')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: ListTile(
              leading: const Icon(Icons.smart_toy_outlined),
              title: const Text('AI 스쿼트 코치 (시연)'),
              subtitle: const Text('실시간 자세 판정 · 횟수 세기 · 세트 저장'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const AiCoachPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.person_outline),
              title: const Text('마이페이지'),
              subtitle: const Text('주간 통계 차트 · 날짜별 세트 기록'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const MyPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.accessibility_new),
              title: const Text('자세 인식 테스트'),
              subtitle: const Text('카메라 + ML Kit 뼈대 표시'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const PoseCameraPage()),
              ),
            ),
          ),
          Card(
            child: ListTile(
              leading: const Icon(Icons.storage),
              title: const Text('로컬 DB 테스트'),
              subtitle: const Text('User / WorkoutSession 저장·조회'),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const DbTestPage()),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
