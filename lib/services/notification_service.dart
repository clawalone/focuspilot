import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest_all.dart' as tz_data;
import 'package:timezone/timezone.dart' as tz;
import 'package:flutter_timezone/flutter_timezone.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/foundation.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'dart:io';

class NotificationService {
  static final NotificationService _instance = NotificationService._internal();
  factory NotificationService() => _instance;
  NotificationService._internal();

  final FlutterLocalNotificationsPlugin _notifications =
      FlutterLocalNotificationsPlugin();
  bool _isInitialized = false;

  /// Background callback for AndroidAlarmManager.
  /// Must be a static or top-level function.
  @pragma('vm:entry-point')
  static Future<void> alarmCallback(int id) async {
    debugPrint('ALARM_MANAGER: Callback triggered for ID=$id');

    // We need to re-initialize notifications in the background isolate
    final ns = NotificationService();
    await ns.init();

    final prefs = await SharedPreferences.getInstance();
    final title = prefs.getString('alarm_title_$id') ?? 'Task Reminder';
    final body = prefs.getString('alarm_body_$id') ?? 'You have a task due!';

    await ns.showNotification(id: id, title: title, body: body);

    // Cleanup
    await prefs.remove('alarm_title_$id');
    await prefs.remove('alarm_body_$id');
    debugPrint('ALARM_MANAGER: Notification sent and cleanup done for ID=$id');
  }

  Future<void> forceInit() async {
    _isInitialized = false;
    await init();
  }

  Future<void> init() async {
    if (_isInitialized) return;

    tz_data.initializeTimeZones();
    final String timeZoneName =
        (await FlutterTimezone.getLocalTimezone()).identifier;
    tz.setLocalLocation(tz.getLocation(timeZoneName));

    const AndroidInitializationSettings androidSettings =
        AndroidInitializationSettings('@mipmap/ic_launcher');

    const AndroidNotificationChannel channelV6 = AndroidNotificationChannel(
      'focus_alerts_v6',
      'MindFlux Alerts (v6)',
      description: 'Critical system-level reminders',
      importance: Importance.max,
      playSound: true,
      enableVibration: true,
      showBadge: true,
      enableLights: true,
    );

    final AndroidFlutterLocalNotificationsPlugin? androidPlugin = _notifications
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >();

    await androidPlugin?.createNotificationChannel(channelV6);

    const DarwinInitializationSettings iosSettings =
        DarwinInitializationSettings(
          requestAlertPermission: true,
          requestBadgePermission: true,
          requestSoundPermission: true,
        );

    const InitializationSettings initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _notifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (NotificationResponse response) {
        debugPrint('NOTIFICATION_CLICKED: ${response.id}');
      },
    );

    _isInitialized = true;
  }

  Future<void> showNotification({
    required int id,
    required String title,
    required String body,
  }) async {
    const AndroidNotificationDetails androidDetails =
        AndroidNotificationDetails(
          'focus_alerts_v6',
          'MindFlux Alerts (v6)',
          channelDescription: 'Critical system-level reminders',
          importance: Importance.max,
          priority: Priority.max,
          showWhen: true,
          ticker: 'Urgent Alert',
        );

    const NotificationDetails details = NotificationDetails(
      android: androidDetails,
      iOS: DarwinNotificationDetails(),
    );

    await _notifications.show(id, title, body, details);
    debugPrint('NOTIFICATION_SENT_IMMEDIATELY (v6): ID=$id');
  }

  Future<void> scheduleNotification({
    required int id,
    required String title,
    required String body,
    required DateTime scheduledDate,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final enabled = prefs.getBool('notifications_enabled') ?? true;
    if (!enabled) return;

    if (Platform.isAndroid) {
      debugPrint(
        'NOTIFICATION_SERVICE: Scheduling via AlarmManager for ID=$id',
      );

      // Save data for the background isolate
      await prefs.setString('alarm_title_$id', title);
      await prefs.setString('alarm_body_$id', body);

      final success = await AndroidAlarmManager.oneShotAt(
        scheduledDate,
        id,
        alarmCallback,
        alarmClock: true,
        allowWhileIdle: true,
        exact: true,
        wakeup: true,
      );

      if (success) {
        debugPrint(
          'NOTIFICATION_SERVICE: AlarmManager scheduled SUCCESS for ID=$id at $scheduledDate',
        );
      } else {
        debugPrint(
          'NOTIFICATION_SERVICE: AlarmManager schedule FAILED for ID=$id',
        );
      }
    } else {
      // Standard iOS scheduling (which isn't having issues)
      final tzNow = tz.TZDateTime.now(tz.local);
      final target = tz.TZDateTime.from(scheduledDate, tz.local);
      if (target.isBefore(tzNow)) return;

      await _notifications.zonedSchedule(
        id,
        title,
        body,
        target,
        const NotificationDetails(iOS: DarwinNotificationDetails()),
        androidScheduleMode: AndroidScheduleMode.exactAllowWhileIdle,
      );
    }
  }

  Future<int> getPendingCount() async {
    // Note: This won't show AlarmManager alarms, only LocalNotifications ones
    final List<PendingNotificationRequest> pending = await _notifications
        .pendingNotificationRequests();
    return pending.length;
  }

  Future<void> cancelNotification(int id) async {
    if (Platform.isAndroid) {
      await AndroidAlarmManager.cancel(id);
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('alarm_title_$id');
      await prefs.remove('alarm_body_$id');
    }
    await _notifications.cancel(id);
  }

  Future<void> cancelAllNotifications() async {
    await _notifications.cancelAll();
  }
}
