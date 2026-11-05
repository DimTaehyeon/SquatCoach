import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

import '../theme/app_theme.dart';
import '../widgets/primary_button.dart';

/// 카메라 권한 요청 (Figma: 권한 / 권한접근)
/// 온보딩에서는 [허용하기]/[나중에 할게요] 모두 사용법 설명(/guide)으로 이동하고,
/// 마이페이지 등에서 다시 들어온 경우에는 뒤로 돌아갑니다.
class PermissionRequestScreen extends StatefulWidget {
  const PermissionRequestScreen({super.key, this.fromOnboarding = true});

  final bool fromOnboarding;

  @override
  State<PermissionRequestScreen> createState() => _PermissionRequestScreenState();
}

class _PermissionRequestScreenState extends State<PermissionRequestScreen> {
  bool _requesting = false;

  Future<void> _request() async {
    setState(() => _requesting = true);
    try {
      final status = await Permission.camera.request(); // OS 권한 창
      if (status.isPermanentlyDenied) await openAppSettings(); // "다시 묻지 않음"이면 설정 화면으로
    } catch (_) {
      // 권한 확인에 실패해도 앱은 계속 진행
    }
    if (mounted) _leave();
  }

  void _leave() {
    if (widget.fromOnboarding) {
      Navigator.of(context).pushReplacementNamed('/guide');
    } else {
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  onPressed: () => Navigator.of(context).maybePop(),
                  icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.textDark),
                ),
              ),
              const SizedBox(height: 24),
              Container(
                width: 88,
                height: 88,
                decoration: const BoxDecoration(color: AppColors.ringTrack, shape: BoxShape.circle),
                child: const Icon(Icons.photo_camera_outlined, size: 40, color: AppColors.primary),
              ),
              const SizedBox(height: 22),
              const Text('카메라 권한이\n필요해요',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.25)),
              const SizedBox(height: 12),
              const Text('스쿼트 자세를 분석하려면\n카메라를 사용해야 해요.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 12.5, color: AppColors.textMuted, height: 1.5)),
              const SizedBox(height: 26),
              Container(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 6),
                decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
                child: const Column(
                  children: [
                    _Point('자세 분석에만 사용해요', '관절 위치를 찾는 데만 카메라 화면을 써요.'),
                    _Point('영상은 저장하지 않아요', '촬영된 영상은 기기에서만 분석되고 저장되지 않아요.'),
                    _Point('언제든 끌 수 있어요', '휴대폰 설정에서 권한을 바꿀 수 있어요.'),
                  ],
                ),
              ),
              const Spacer(),
              PrimaryButton(label: '허용하기', isLoading: _requesting, onPressed: _request),
              const SizedBox(height: 6),
              TextButton(
                onPressed: _leave,
                child: const Text('나중에 할게요', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _Point extends StatelessWidget {
  const _Point(this.title, this.desc);
  final String title;
  final String desc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
            child: const Icon(Icons.check_rounded, size: 14, color: AppColors.primary),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w700, color: AppColors.textDark)),
                const SizedBox(height: 2),
                Text(desc, style: const TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
