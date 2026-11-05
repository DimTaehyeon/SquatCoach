import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_tts/flutter_tts.dart';

import '../../config/squat_criteria.dart' show CheckRole, SquatFault;

/// 자세 오류가 났을 때 "경고음 + 짧은 음성(TTS)"으로 알려주는 도우미.
///
/// 화면 문구는 실시간으로 계속 바뀌지만, 소리는 지저분해지지 않게 아래 규칙으로만 냅니다.
///  1. 판정 대상 오류(다리 모아짐 / 무릎 덜 굽힘 / 몸 기울어짐)만 소리를 냅니다. 참고 항목은 화면 문구만.
///  2. 한 번 앉았다 일어서는 동안 같은 오류는 한 번만 (호출하는 쪽에서 관리)
///  3. 어떤 소리든 [minGapMs] 이내에는 다시 내지 않고, 같은 오류는 [sameFaultGapMs] 이내에는 반복하지 않음
///  4. 말은 오류당 한 문장으로 짧게 — 멀리서도 들리게 "경고음 → 음성" 순서로 재생
class AlertCoach {
  FlutterTts? _tts;
  AudioPlayer? _player;
  bool _ready = false;

  bool voiceEnabled = true; // 음성 안내(TTS)
  bool soundEnabled = true; // 경고음

  final Stopwatch _clock = Stopwatch()..start();
  int _lastAnyMs = -1000000;
  final Map<SquatFault, int> _lastByFault = {};

  static const int minGapMs = 2500;
  static const int sameFaultGapMs = 6000;

  /// 오류별 음성 문구 (한 문장, 짧게)
  static String? voiceText(SquatFault f) {
    switch (f) {
      case SquatFault.kneeCaving:
        return '무릎이 모여요. 바깥으로 밀어주세요.';
      case SquatFault.shallowDepth:
        return '더 깊이 앉아주세요.';
      case SquatFault.lateralTilt:
        return '몸이 기울었어요. 중심을 잡아주세요.';
      default:
        return null; // 참고 항목은 소리 없음
    }
  }

  Future<void> init() async {
    try {
      final tts = FlutterTts();
      await tts.setLanguage('ko-KR');
      await tts.setSpeechRate(0.5);
      await tts.setVolume(1.0);
      await tts.setPitch(1.0);
      _tts = tts;
    } catch (e) {
      debugPrint('TTS 초기화 실패: $e');
    }
    try {
      final player = AudioPlayer();
      await player.setReleaseMode(ReleaseMode.stop);
      _player = player;
    } catch (e) {
      debugPrint('경고음 초기화 실패: $e');
    }
    _ready = true;
  }

  /// 오류가 났을 때 호출. 규칙(1·3)에 맞지 않으면 아무 소리도 내지 않습니다.
  Future<void> alert(SquatFault fault) async {
    if (!_ready || fault.role != CheckRole.judged) return;
    if (!voiceEnabled && !soundEnabled) return;
    final now = _clock.elapsedMilliseconds;
    if (now - _lastAnyMs < minGapMs) return;
    final last = _lastByFault[fault];
    if (last != null && now - last < sameFaultGapMs) return;
    _lastAnyMs = now;
    _lastByFault[fault] = now;

    try {
      if (soundEnabled) await _player?.play(AssetSource('sounds/alert.wav'));
      if (voiceEnabled) {
        final text = voiceText(fault);
        if (text != null) {
          if (soundEnabled) await Future<void>.delayed(const Duration(milliseconds: 450)); // 경고음이 끝난 뒤 말하기
          await _tts?.speak(text);
        }
      }
    } catch (e) {
      debugPrint('경고 소리 재생 실패: $e');
    }
  }

  /// 정자세로 1회를 끝냈을 때 횟수를 우리말 수로 읽어줍니다. ("하나", "둘", … "열", "열하나" …)
  /// 음성 안내가 꺼져 있으면 읽지 않습니다. 오류가 난 회는 호출하지 않습니다.
  Future<void> countRep(int n) async {
    if (!_ready || !voiceEnabled || n <= 0) return;
    try {
      await _tts?.speak(koreanCount(n));
    } catch (e) {
      debugPrint('횟수 읽기 실패: $e');
    }
  }

  /// 1~99 를 "하나, 둘, 셋 … 열, 열하나 … 스물, 스물하나 …" 로 바꿉니다. 100 이상은 숫자 그대로.
  static String koreanCount(int n) {
    if (n <= 0 || n >= 100) return '$n';
    const ones = ['', '하나', '둘', '셋', '넷', '다섯', '여섯', '일곱', '여덟', '아홉'];
    const tens = ['', '열', '스물', '서른', '마흔', '쉰', '예순', '일흔', '여든', '아흔'];
    return '${tens[n ~/ 10]}${ones[n % 10]}';
  }

  Future<void> stop() async {
    try {
      await _tts?.stop();
      await _player?.stop();
    } catch (_) {}
  }

  Future<void> dispose() async {
    await stop();
    try {
      await _player?.dispose();
    } catch (_) {}
    _tts = null;
    _player = null;
    _ready = false;
  }
}
