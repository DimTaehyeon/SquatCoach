import 'package:flutter/material.dart';

import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';

/// 앱 실행 로딩 화면 (Figma: 앱실행로딩화면).
/// 로고가 튕기며 등장하고, 로고 뒤 빛이 숨 쉬듯 커졌다 작아지며,
/// 아래 진행률 바가 퍼센트와 함께 차오릅니다. 끝나면 (처음이면) 프로필 입력, (이미 가입했으면) 홈으로 이동합니다.
///
/// 나중에 실제 초기화 작업(저장된 프로필 불러오기, 모델 로딩 등)이 생기면
/// 그 작업이 끝난 시점에 맞춰 이동하도록 바꾸면 됩니다.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with TickerProviderStateMixin {
  late final AnimationController _progress = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 2600),
  );
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1200),
  )..repeat(reverse: true);

  late final Animation<double> _logoScale = CurvedAnimation(
    parent: _progress,
    curve: const Interval(0.0, 0.35, curve: Curves.elasticOut),
  );
  late final Animation<double> _logoFade = CurvedAnimation(
    parent: _progress,
    curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
  );
  late final Animation<double> _barValue = CurvedAnimation(parent: _progress, curve: Curves.easeInOut);

  @override
  void initState() {
    super.initState();
    _progress.forward().whenComplete(_goNext);
  }

  /// 저장된 프로필을 다 불러온 뒤, 이미 가입(온보딩)한 사용자는 바로 홈으로, 처음이면 프로필 입력으로 갑니다.
  Future<void> _goNext() async {
    final profile = context.read<ProfileProvider>();
    await profile.ready;
    if (!mounted) return;
    Navigator.of(context).pushReplacementNamed(profile.user.onboarded ? '/main' : '/profile');
  }

  @override
  void dispose() {
    _progress.dispose();
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.splashGradient),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      AnimatedBuilder(
                        animation: Listenable.merge([_progress, _pulse]),
                        builder: (context, _) {
                          return Opacity(
                            opacity: _logoFade.value,
                            child: Transform.scale(
                              scale: 0.4 + 0.6 * _logoScale.value,
                              child: Container(
                                width: 120,
                                height: 120,
                                decoration: BoxDecoration(
                                  borderRadius: BorderRadius.circular(26),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.18 + 0.10 * _pulse.value),
                                      blurRadius: 20 + 20 * _pulse.value,
                                      spreadRadius: 1 + 4 * _pulse.value,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                child: ClipRRect(
                                  borderRadius: BorderRadius.circular(26),
                                  child: Image.asset('assets/images/logo.png', fit: BoxFit.cover),
                                ),
                              ),
                            ),
                          );
                        },
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'AI가 함께하는 스쿼트 자세 코칭',
                        style: TextStyle(fontSize: 12, color: Colors.white70, fontWeight: FontWeight.w500),
                      ),
                    ],
                  ),
                ),
              ),
              AnimatedBuilder(
                animation: _barValue,
                builder: (context, _) {
                  final percent = (_barValue.value * 100).round();
                  return Column(
                    children: [
                      SizedBox(
                        width: 160,
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: LinearProgressIndicator(
                            value: _barValue.value,
                            minHeight: 5,
                            backgroundColor: Colors.white24,
                            valueColor: const AlwaysStoppedAnimation(Colors.white),
                          ),
                        ),
                      ),
                      const SizedBox(height: 10),
                      Text('불러오는 중...  $percent%', style: const TextStyle(fontSize: 11, color: Colors.white60)),
                    ],
                  );
                },
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}
