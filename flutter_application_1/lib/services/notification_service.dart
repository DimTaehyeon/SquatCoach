import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// 매일 정해진 시간에 운동 알림 (flutter_local_notifications ^22)
///
/// 서버 없이 폰이 직접 알림을 예약합니다.
class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  static const _dailyId = 1;
  final _plugin = FlutterLocalNotificationsPlugin();
  bool _ready = false;

  Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    // 팀 대상 사용자가 한국이라 고정. 해외 지원이 필요하면 flutter_timezone 패키지로 바꾸면 됨
    tz.setLocalLocation(tz.getLocation('Asia/Seoul'));
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
      iOS: DarwinInitializationSettings(
        // 권한은 사용자가 알림을 켤 때 물어봄
        requestAlertPermission: false,
        requestSoundPermission: false,
        requestBadgePermission: false,
      ),
    );
    await _plugin.initialize(settings: settings);
    _ready = true;
  }

  /// 알림 권한 요청. 허용하면 true
  Future<bool> requestPermission() async {
    await init();
    final ios = _plugin.resolvePlatformSpecificImplementation<
        IOSFlutterLocalNotificationsPlugin>();
    if (ios != null) {
      return await ios.requestPermissions(alert: true, sound: true) ?? false;
    }
    final android = _plugin.resolvePlatformSpecificImplementation<
        AndroidFlutterLocalNotificationsPlugin>();
    if (android != null) {
      return await android.requestNotificationsPermission() ?? false;
    }
    return false;
  }

  /// 매일 [hour]:[minute]에 알림
  Future<void> scheduleDaily(int hour, int minute) async {
    await init();
    await _plugin.cancel(id: _dailyId);
    final now = tz.TZDateTime.now(tz.local);
    var at = tz.TZDateTime(tz.local, now.year, now.month, now.day, hour, minute);
    if (!at.isAfter(now)) at = at.add(const Duration(days: 1));
    await _plugin.zonedSchedule(
      id: _dailyId,
      title: '스쿼트할 시간이에요',
      body: '오늘의 스쿼트로 하체를 깨워 볼까요? 정확한 자세는 앱이 봐 드릴게요.',
      scheduledDate: at,
      notificationDetails: const NotificationDetails(
        android: AndroidNotificationDetails(
          'daily_reminder',
          '운동 알림',
          channelDescription: '매일 정해진 시간에 운동을 알려 줍니다',
        ),
        iOS: DarwinNotificationDetails(),
      ),
      androidScheduleMode: AndroidScheduleMode.inexactAllowWhileIdle,
      matchDateTimeComponents: DateTimeComponents.time, // 매일 같은 시간 반복
    );
    debugPrint('운동 알림 예약: 매일 $hour:$minute (다음 알림 $at)');
  }

  Future<void> cancelDaily() async {
    await init();
    await _plugin.cancel(id: _dailyId);
  }
}
