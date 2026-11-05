import 'package:flutter/material.dart';

import '../models/user_profile.dart';

/// 프로필 사진이 있으면 사진을, 없으면 이름의 첫 글자를 보여주는 둥근 사각형 아바타.
class ProfileAvatar extends StatelessWidget {
  const ProfileAvatar({
    super.key,
    required this.user,
    this.size = 40,
    this.radius = 12,
    this.fontSize = 15,
    this.color,
    this.gradient,
  });

  final UserProfile user;
  final double size;
  final double radius;
  final double fontSize;
  final Color? color;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final photo = user.photoBytes;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: color, gradient: gradient, borderRadius: BorderRadius.circular(radius)),
      child: photo != null
          ? Image.memory(photo, width: size, height: size, fit: BoxFit.cover, gaplessPlayback: true)
          : Text(user.initial, style: TextStyle(color: Colors.white, fontSize: fontSize, fontWeight: FontWeight.w700)),
    );
  }
}
