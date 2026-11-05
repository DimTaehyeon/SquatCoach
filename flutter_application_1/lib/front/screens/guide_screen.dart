import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/profile_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/figure_painter.dart';
import '../widgets/primary_button.dart';

/// 사용법 설명 3장 (Figma: 설명 2/3, Frame 5 = 3/3).
/// 1/3은 시안이 없어서 같은 스타일로 새로 만든 화면입니다. 시안이 있으면 알려주세요.
class GuideScreen extends StatefulWidget {
  const GuideScreen({super.key});

  @override
  State<GuideScreen> createState() => _GuideScreenState();
}

class _GuideScreenState extends State<GuideScreen> {
  final _controller = PageController();
  int _page = 0;
  static const _total = 3;

  void _finish() {
    context.read<ProfileProvider>().markOnboarded();
    Navigator.of(context).pushNamedAndRemoveUntil('/main', (route) => false);
  }

  void _next() {
    if (_page == _total - 1) {
      _finish();
    } else {
      _controller.nextPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  void _back() {
    if (_page == 0) {
      Navigator.of(context).maybePop();
    } else {
      _controller.previousPage(duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
              child: Row(
                children: [
                  IconButton(
                    onPressed: _back,
                    icon: const Icon(Icons.chevron_left_rounded, size: 28, color: AppColors.textDark),
                  ),
                  const Spacer(),
                  TextButton(
                    onPressed: _finish,
                    child: const Text('건너뛰기', style: TextStyle(color: AppColors.textMuted, fontSize: 12)),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PageView(
                controller: _controller,
                onPageChanged: (i) => setState(() => _page = i),
                children: const [
                  _GuidePage(
                    step: '1 / 3',
                    title: '스쿼트 자세를\nAI가 실시간으로 봐줘요',
                    body: '카메라로 관절을 인식해서 무릎·허리 자세를 바로 알려드려요.',
                    illustration: _SkeletonIllustration(),
                  ),
                  _GuidePage(
                    step: '2 / 3',
                    title: '정면에서 찍으면\n돼요',
                    body: '휴대폰을 2~3m 떨어진 곳에 세우고,\n몸 전체가 나오도록 카메라를 정면으로 보고 서 주세요.',
                    illustration: _FrontViewIllustration(),
                  ),
                  _GuidePage(
                    step: '3 / 3',
                    title: '자세가 좋아지는 걸\n눈으로 확인해요',
                    body: '운동할 때마다 정확도와 횟수가 기록돼서,\n내 변화를 한눈에 볼 수 있어요.',
                    illustration: _ChartIllustration(),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(
                _total,
                (i) => AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  margin: const EdgeInsets.symmetric(horizontal: 3),
                  width: i == _page ? 18 : 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: i == _page ? AppColors.primary : AppColors.cardBorder,
                    borderRadius: BorderRadius.circular(3),
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
              child: PrimaryButton(label: _page == _total - 1 ? '시작하기' : '다음', onPressed: _next),
            ),
          ],
        ),
      ),
    );
  }
}

class _GuidePage extends StatelessWidget {
  const _GuidePage({required this.step, required this.title, required this.body, required this.illustration});

  final String step;
  final String title;
  final String body;
  final Widget illustration;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(color: AppColors.ringTrack, borderRadius: BorderRadius.circular(28)),
              child: illustration,
            ),
          ),
          const SizedBox(height: 18),
          Text(step, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: AppColors.textDark)),
          const SizedBox(height: 4),
          Text(title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: AppColors.textDark, height: 1.25)),
          const SizedBox(height: 8),
          Text(body, style: const TextStyle(fontSize: 12, color: AppColors.textMuted, height: 1.5)),
          const SizedBox(height: 18),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- 1/3 일러스트
class _SkeletonIllustration extends StatelessWidget {
  const _SkeletonIllustration();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 170,
        height: 230,
        decoration: BoxDecoration(gradient: AppColors.cameraGradient, borderRadius: BorderRadius.circular(22)),
        padding: const EdgeInsets.all(14),
        child: const AnimatedPoseOverlay(),
      ),
    );
  }
}

// ---------------------------------------------------------------- 2/3 일러스트 (휴대폰 + 정면 사람)
class _FrontViewIllustration extends StatelessWidget {
  const _FrontViewIllustration();

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(child: CustomPaint(painter: _FrontViewPainter())),
        Align(
          alignment: const Alignment(0.05, 0.86),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
            decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(14)),
            child: const Text('2~3m', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textDark)),
          ),
        ),
      ],
    );
  }
}

class _FrontViewPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    Offset o(double x, double y) => Offset(x * w, y * h);

    final ground = Paint()
      ..color = const Color(0xFFA9BEA9)
      ..strokeWidth = 2;
    canvas.drawLine(o(0.06, 0.74), o(0.94, 0.74), ground);

    // 휴대폰
    final phone = RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12, h * 0.40, 36, 74), const Radius.circular(8));
    canvas.drawRRect(phone, Paint()..color = AppColors.screenDark);
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTWH(w * 0.12 + 5, h * 0.40 + 8, 26, 56), const Radius.circular(4)),
      Paint()..color = const Color(0xFF2F4A3E),
    );
    final cam = Offset(w * 0.12 + 36, h * 0.40 + 14);
    canvas.drawCircle(cam, 3.5, Paint()..color = AppColors.warningYellow);

    // 점선 시야
    final yellow = Paint()
      ..color = AppColors.warningYellow
      ..strokeWidth = 1.6;
    _dashed(canvas, cam, o(0.74, 0.20), yellow);
    _dashed(canvas, cam, o(0.74, 0.74), yellow);

    // 정면 사람
    final body = Paint()
      ..color = AppColors.primaryDark
      ..style = PaintingStyle.stroke
      ..strokeWidth = 5
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    // 정면: 머리, 어깨선, 몸통, 양팔, 양다리
    canvas.drawCircle(o(0.74, 0.20), 10, Paint()..color = AppColors.primaryDark);
    Path line(List<Offset> pts) {
      final p = Path()..moveTo(pts.first.dx, pts.first.dy);
      for (final pt in pts.skip(1)) {
        p.lineTo(pt.dx, pt.dy);
      }
      return p;
    }
    canvas.drawPath(line([o(0.68, 0.32), o(0.80, 0.32)]), body); // 어깨
    canvas.drawPath(line([o(0.74, 0.30), o(0.74, 0.52)]), body); // 몸통
    canvas.drawPath(line([o(0.68, 0.32), o(0.64, 0.46)]), body); // 왼팔
    canvas.drawPath(line([o(0.80, 0.32), o(0.84, 0.46)]), body); // 오른팔
    canvas.drawPath(line([o(0.74, 0.52), o(0.69, 0.62), o(0.69, 0.73)]), body); // 왼다리
    canvas.drawPath(line([o(0.74, 0.52), o(0.79, 0.62), o(0.79, 0.73)]), body); // 오른다리

    // 거리 화살표
    final arrow = Paint()
      ..color = AppColors.textDark
      ..strokeWidth = 1.6
      ..strokeCap = StrokeCap.round;
    final a = o(0.16, 0.86);
    final b = o(0.74, 0.86);
    canvas.drawLine(a, b, arrow);
    for (final tip in [a, b]) {
      final dir = tip == a ? 1.0 : -1.0;
      canvas.drawLine(tip, Offset(tip.dx + dir * 7, tip.dy - 4), arrow);
      canvas.drawLine(tip, Offset(tip.dx + dir * 7, tip.dy + 4), arrow);
    }
  }

  void _dashed(Canvas canvas, Offset p1, Offset p2, Paint paint) {
    const dash = 6.0;
    const gap = 5.0;
    final total = (p2 - p1).distance;
    final dir = (p2 - p1) / total;
    var d = 0.0;
    while (d < total) {
      final s = p1 + dir * d;
      final e = p1 + dir * math.min(d + dash, total);
      canvas.drawLine(s, e, paint);
      d += dash + gap;
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ---------------------------------------------------------------- 3/3 일러스트 (정확도 차트 카드)
class _ChartIllustration extends StatelessWidget {
  const _ChartIllustration();

  static const _heights = [0.34, 0.42, 0.48, 0.58, 0.66, 0.92];

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 22),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
        decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(18)),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('평균 자세 정확도', style: TextStyle(fontSize: 10.5, color: AppColors.textMuted)),
            const SizedBox(height: 4),
            Row(
              children: [
                const Text('87.4%', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textDark)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                  decoration: BoxDecoration(color: AppColors.ringTrack, borderRadius: BorderRadius.circular(10)),
                  child: const Text('+12%p',
                      style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: AppColors.primary)),
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 110,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  for (var i = 0; i < _heights.length; i++)
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: TweenAnimationBuilder<double>(
                          tween: Tween(begin: 0, end: _heights[i]),
                          duration: Duration(milliseconds: 500 + i * 120),
                          curve: Curves.easeOutCubic,
                          builder: (context, v, _) => FractionallySizedBox(
                            heightFactor: v,
                            alignment: Alignment.bottomCenter,
                            child: Container(
                              decoration: BoxDecoration(
                                color: i == _heights.length - 1 ? AppColors.primary : AppColors.barLight,
                                borderRadius: BorderRadius.circular(5),
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 8),
            const Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('1주차', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
                Text('6주차', style: TextStyle(fontSize: 9.5, color: AppColors.textMuted)),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
