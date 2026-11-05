# SquatCoach (3조)

스마트폰 카메라 하나로 스쿼트 자세를 실시간으로 판정하는 Flutter 앱입니다.
영상은 저장·전송하지 않고 폰 안에서만 분석합니다 (온디바이스).

- 자세 인식: Google ML Kit Pose Detection (스트림 모드, 관절 33개)
- 판정: 기획 판정 기준 v0.2 규칙 + AI 모델(TFLite → Dart 이식, 참고 표시)
- 저장: 기기 내부 SQLite (운동 → 세트 → 반복)

---

## 1. 처음 한 번만: 개발 환경

| 필요한 것 | Android 폰으로 테스트 | iPhone으로 테스트 |
|---|---|---|
| 컴퓨터 | Windows / Mac 모두 가능 | **Mac만 가능** |
| Flutter SDK | ✅ | ✅ |
| Android Studio (Android SDK) | ✅ | - |
| Xcode + CocoaPods | - | ✅ (`brew install cocoapods`) |
| Apple ID (무료 가능) | - | ✅ |

설치 후 터미널에서 확인:
```bash
flutter doctor
```
사용할 기기 쪽 항목에 ✓ 가 나오면 됩니다.

## 2. 코드 받기

```bash
git clone https://github.com/DimTaehyeon/SquatCoach.git
cd SquatCoach
git checkout main          # 아직 합쳐지기 전이면 ai-coach
cd squatcoach
flutter pub get
```

> ⚠️ 프로젝트 폴더를 iCloud와 동기화되는 폴더(바탕화면, 문서)에 두면 iPhone 빌드가 실패합니다.
> `~/dev` 처럼 동기화되지 않는 폴더에 받으세요.

## 3-A. Android 폰에서 실행

1. 폰: 설정 → 휴대전화 정보 → 소프트웨어 정보 → **빌드번호 7번 누르기** → 개발자 옵션 → **USB 디버깅 켜기**
2. 케이블로 연결 후 폰에 뜨는 "USB 디버깅 허용" 누르기
3. 실행
```bash
flutter devices                    # 폰이 목록에 보이는지 확인
flutter run --profile -d <기기ID>   # --profile: 실제 속도로 실행
```

**APK 파일만 받아서 설치하는 경우** (개발 환경 없이 써 보기)
- 전달받은 `SquatCoach.apk`를 폰에서 열기 → "출처를 알 수 없는 앱 설치" 허용 → 설치

## 3-B. iPhone에서 실행 (Mac 필요)

무료 Apple ID는 앱 파일을 다른 사람에게 보낼 수 없어서, **각자 자기 Mac에서 자기 Apple ID로 설치**해야 합니다.

1. iPhone: 설정 → 개인정보 보호 및 보안 → **개발자 모드 켜기** (재시동)
2. Xcode로 서명 설정
```bash
cd ios && pod install && cd ..
open ios/Runner.xcworkspace
```
   - 왼쪽 **Runner** → **Signing & Capabilities**
   - **Team**: 본인 Apple ID (Personal Team)
   - **Bundle Identifier**: 겹치지 않게 바꾸기 (예: `com.본인이니셜.squatcoach`)
   - 위쪽 **Debug / Release / Profile** 탭 모두 똑같이
3. 실행
```bash
flutter run --profile -d <기기ID>
```
4. 앱이 "신뢰하지 않는 개발자"로 안 열리면: iPhone 설정 → 일반 → VPN 및 기기 관리 → 본인 Apple ID → **신뢰**

> 무료 Apple ID로 설치한 앱은 **7일 후 만료**됩니다. 다시 `flutter run` 하면 됩니다.
> ⚠️ Bundle Identifier는 Xcode에서만 바꾸고 **커밋하지 마세요** (다른 팀원 서명이 깨짐).

## 4. 앱 사용법

1. **운동** 탭 → 운동 시작
2. 폰을 허리 높이에 세우고 2~3m 떨어져 정면으로 서기 (머리~발끝이 화면에 들어오게)
3. 2초간 똑바로 서 있기 → 영점 조절 완료
4. 스쿼트 → 1회마다 정자세/오류 판정
5. **세트 완료** → 다음 세트 / **운동 종료** → 결과 화면, 기록 저장

- **홈**: 주간 그래프, 최근 기록
- **마이페이지**: 프로필, 누적 통계, 운동 알림
- **개발자 도구** (자세 인식 테스트, DB 테스트, 가짜 기록 넣기): 마이페이지의 **프로필 카드를 길게 누르기**

## 5. 자주 나는 오류

| 메시지 | 해결 |
|---|---|
| `CocoaPods not installed` / Ruby 오류 | `brew install cocoapods` |
| `No valid code signing certificates` | Xcode에서 Team 선택 (3-B의 2번) |
| `Failed to register bundle identifier` | Bundle Identifier를 다른 이름으로 |
| `Developer Mode disabled` | iPhone 개발자 모드 켜기 → 재시동 |
| 카메라 화면이 검정 | 폰 설정에서 SquatCoach 카메라 권한 허용 |
| Android `flutter devices`에 폰이 안 보임 | USB 디버깅 켜기, 케이블 바꿔 보기, "파일 전송" 모드 |

## 6. 폴더 구조

```
lib/
├─ main.dart                 하단 탭 (홈 / 운동 / 마이페이지)
├─ pages/                    화면
├─ workout/                  운동 진행 (영점 → 세트 → 저장)
├─ ai/                       특징값 계산, AI 모델, 규칙 판정
├─ config/                   판정 기준값, 칼로리 계산식 ← 숫자만 바꾸면 기준 변경
├─ db/                       SQLite 저장·조회
└─ services/                 알림
test/python_parity_test.dart Python(학습) ↔ Dart(앱) 계산 일치 확인: flutter test
```

---
## 프론트엔드 병합 (lib/front)
백엔드 앱(자세 인식·판정·DB)을 그대로 두고, 프론트엔드의 Figma 화면을 `lib/front` 아래에 얹었습니다.

- 진입점: `lib/main.dart` (프론트 화면 흐름) — 예전 탭 화면(`lib/pages/*`, `lib/ui`)은 쓰이지 않고 남겨 둠
- 화면: `lib/front/screens` (스플래시 → 프로필 → 목표 → 권한 → 사용법 → 홈/운동/기록/마이)
- 운동 화면: `lib/front/screens/analysis_screen.dart` — 카메라 프레임을 `WorkoutController`에 넘기고 결과를 표시
- 상태: `lib/front/providers/session_provider.dart` — `WorkoutController` 상태를 화면에 전달, 세트/횟수/휴식 설정, 판정 모드(초보자/일반)
- 기록: 백엔드 SQLite → `lib/front/repositories/db_workout_repository.dart` 가 화면용 모델로 변환 (정확도 = 정자세 ÷ 전체)
- 프로필: shared_preferences (이름·성별·목표·키·몸무게·사진·알림 시각). 알림은 백엔드 `NotificationService` 사용
- 백엔드 코드 수정: `WorkoutController.discardCurrentSet()` 한 개만 추가 ("이번 세트 다시 하기")
- 개발자 도구: 마이페이지 프로필 카드 길게 누르기
- 음성 안내(TTS)는 이번 병합에서 제외

## 오류 소리 안내 (경고음 + 음성)
- `lib/front/services/alert_coach.dart` — 판정 대상 오류(다리 모아짐/무릎 덜 굽힘/몸 기울어짐)만 소리로 알림, 참고 항목은 화면 문구만
- 규칙: 한 번 앉는 동안 같은 오류 1회, 어떤 소리든 2.5초 간격, 같은 오류는 6초 간격 (값은 `AlertCoach` 상수)
- 켜고 끄기: 운동 화면 우상단 스피커 아이콘 / 마이페이지 "운동 중 안내" (음성, 경고음 각각)
- 횟수 읽기: 정자세로 1회를 끝낼 때마다 "하나, 둘…"(정자세 횟수 기준). 오류가 난 회는 세지 않고 경고음+오류 음성만. 음성 안내 스위치를 끄면 횟수도 읽지 않음
- 시작 카운트다운(3-2-1): 첫 시작과 휴식 뒤 다음 세트 시작 때 `/countdown` 화면 → 끝나면 영점 조절 시작

## 화면 흐름 (Figma 복원)
카메라 준비(실제 카메라로 전신·정면·밝기 확인) → 3-2-1 카운트다운 → 운동 분석(영점 조절 → 세트) ⇄ 일시정지 → 휴식 → 카운트다운 → … → 결과
영점 조절 중 12초 넘게 몸이 안 보이면 '인식 실패' 화면이 뜹니다.
