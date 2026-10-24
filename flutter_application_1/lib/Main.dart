import 'package:flutter/material.dart';
 
import '../pose_camera_page.dart';
 
void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const PoseApp());
}
 
class PoseApp extends StatelessWidget {
  const PoseApp({super.key});
 
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Pose Test',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(useMaterial3: true),
      home: const PoseCameraPage(),
    );
  }
}
 