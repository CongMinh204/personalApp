import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;

/// Giao diện tách riêng để test controller không cần plugin thật.
abstract class TimerNotifier {
  Future<void> ensurePermissions();
  Future<void> scheduleEnd({
    required DateTime at,
    required String title,
    required String body,
  });
  Future<void> cancelEnd();
}

/// Đặt thông báo "hết giờ" phòng khi app chạy nền (SRS 1.4.3 #5, UC12 bước 3).
/// Chỉ hoạt động trên Android / iOS / macOS; nền tảng khác thì bỏ qua.
class TimerNotificationService implements TimerNotifier {
  TimerNotificationService._();
  static final instance = TimerNotificationService._();

  final _plugin = FlutterLocalNotificationsPlugin();

  // Hai id luân phiên để khi tự chạy phiên kế tiếp không đè lên thông báo
  // của phiên vừa xong (nếu nó chưa kịp hiện).
  static const _ids = [9001, 9002];
  int _next = 0;

  bool _ready = false;
  bool _askedPermission = false;
  Future<void>? _initFuture;

  static bool get _platformSupported =>
      !kIsWeb &&
      (defaultTargetPlatform == TargetPlatform.android ||
          defaultTargetPlatform == TargetPlatform.iOS ||
          defaultTargetPlatform == TargetPlatform.macOS);

  static const _details = NotificationDetails(
    android: AndroidNotificationDetails(
      'timer_channel',
      'Hẹn giờ',
      channelDescription: 'Thông báo khi hết phiên Pomodoro / đếm ngược',
      importance: Importance.max,
      priority: Priority.high,
    ),
    iOS: DarwinNotificationDetails(),
    macOS: DarwinNotificationDetails(),
  );

  /// An toàn khi gọi nhiều lần / đồng thời: chỉ khởi tạo một lần.
  /// Các hàm bên dưới tự gọi, nên không cần gọi trong main().
  Future<void> init() => _initFuture ??= _doInit();

  Future<void> _doInit() async {
    if (!_platformSupported) return;
    try {
      tzdata.initializeTimeZones(); // TZDateTime.from vẫn đúng thời điểm tuyệt đối
      await _plugin.initialize(
        const InitializationSettings(
          android: AndroidInitializationSettings('@mipmap/ic_launcher'),
          iOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
          macOS: DarwinInitializationSettings(
            requestAlertPermission: false,
            requestBadgePermission: false,
            requestSoundPermission: false,
          ),
        ),
      );
      _ready = true;
    } catch (e) {
      debugPrint('Không khởi tạo được thông báo: $e');
    }
  }

  /// Xin quyền một lần, khi người dùng bắt đầu phiên đầu tiên.
  @override
  Future<void> ensurePermissions() async {
    await init();
    if (!_ready || _askedPermission) return;
    _askedPermission = true;
    try {
      final android = _plugin
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >();
      await android?.requestNotificationsPermission();
      await android?.requestExactAlarmsPermission();
      await _plugin
          .resolvePlatformSpecificImplementation<
            IOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
      await _plugin
          .resolvePlatformSpecificImplementation<
            MacOSFlutterLocalNotificationsPlugin
          >()
          ?.requestPermissions(alert: true, badge: true, sound: true);
    } catch (e) {
      debugPrint('Không xin được quyền thông báo: $e');
    }
  }

  @override
  Future<void> scheduleEnd({
    required DateTime at,
    required String title,
    required String body,
  }) async {
    await init();
    if (!_ready || !at.isAfter(DateTime.now())) return;
    final id = _ids[_next];
    _next = (_next + 1) % _ids.length;
    try {
      await _plugin.zonedSchedule(
        id,
        title,
        body,
        tz.TZDateTime.from(at, tz.local),
        _details,
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    } catch (e) {
      // Ví dụ Android 12+ chưa cấp quyền báo thức chính xác: đồng hồ trong
      // app vẫn chạy, chỉ không có thông báo khi app ở nền.
      debugPrint('Không đặt được thông báo hết giờ: $e');
    }
  }

  @override
  Future<void> cancelEnd() async {
    await init();
    if (!_ready) return;
    try {
      for (final id in _ids) {
        await _plugin.cancel(id);
      }
    } catch (e) {
      debugPrint('Không hủy được thông báo: $e');
    }
  }
}
