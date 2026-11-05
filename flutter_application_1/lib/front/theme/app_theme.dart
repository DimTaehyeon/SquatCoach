import 'package:flutter/material.dart';

/// Figma 디자인에서 쓰인 색상/스타일을 한 곳에 모아둔 파일.
/// 색을 바꿀 땐 여기만 고치면 앱 전체에 반영됩니다.
class AppColors {
  AppColors._();

  static const background = Color(0xFFF3EEDF);
  static const cardBorder = Color(0xFFE6E0CE);
  static const textDark = Color(0xFF1E2B23);
  static const textMuted = Color(0xFF7C8B75);
  static const textFaint = Color(0xFFA3AC9C);

  static const primary = Color(0xFF1F6B4F);
  static const primaryDark = Color(0xFF184F3D);
  static const primaryLight = Color(0xFF2E8B63);
  static const primarySoft = Color(0xFFE1F0E5);
  static const accentMint = Color(0xFF63D98B);

  static const danger = Color(0xFFB84A3E);
  static const dangerSoft = Color(0xFFFBE4E0);
  static const warningBg = Color(0xFFFFF3DD);
  static const warningText = Color(0xFFC98A1E);
  static const warningYellow = Color(0xFFF2C230);
  static const amber = Color(0xFFE8A93B);

  static const ringTrack = Color(0xFFDCE8DA);
  static const barLight = Color(0xFFD3E3D3);

  static const pageDark = Color(0xFF141C19);
  static const screenDark = Color(0xFF1F2E27);
  static const screenDarkBottom = Color(0xFF18241F);
  static const darkBgTop = Color(0xFF2B3B33);
  static const darkBgBottom = Color(0xFF182420);

  static const splashTop = Color(0xFF1B5A45);
  static const splashBottom = Color(0xFF36936B);

  static const primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [primaryDark, primary, primaryLight],
  );

  static const cameraGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [darkBgTop, darkBgBottom],
  );

  static const splashGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [splashTop, splashBottom],
  );
}

class AppRadius {
  AppRadius._();
  static const card = 16.0;
  static const cardLarge = 20.0;
  static const button = 14.0;
  static const pill = 20.0;
}

ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: AppColors.background,
    // 한글 폰트를 추가하려면 assets/fonts에 ttf를 넣고 pubspec.yaml의
    // flutter: fonts: 섹션에 등록한 뒤 여기에 fontFamily: '폰트이름' 을 지정하세요.
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      primary: AppColors.primary,
      surface: AppColors.background,
    ),
    textTheme: const TextTheme(
      bodyMedium: TextStyle(color: AppColors.textDark),
    ),
  );
}
