import 'dart:isolate';
import 'dart:ui';
import 'package:awesome_notifications/awesome_notifications.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'database_service.dart';
import '../models/todo.dart';
import '../main.dart'; // To access navigator key
import '../screens/timer_screen.dart';
import 'firestore_service.dart';

class ReminderService {
  static final ReminderService _instance = ReminderService._internal();
  factory ReminderService() => _instance;
  ReminderService._internal();

  Future<void> initialize() async {
    debugPrint('Initializing ReminderService...');

    // Initialize Awesome Notifications
    await AwesomeNotifications().initialize(
      // set the icon to null if you want to use the default app icon
      null,
      [
        NotificationChannel(
          channelKey: 'mission_channel',
          channelName: 'Mission Alerts',
          channelDescription: 'Interactive reminders for your missions',
          defaultColor: const Color(0xFF00BCD4),
          ledColor: Colors.white,
          importance: NotificationImportance.High,
          channelShowBadge: true,
          onlyAlertOnce: true,
          playSound: true,
          criticalAlerts: true,
        ),
      ],
      debug: true,
    );

    AwesomeNotifications().setListeners(
      onActionReceivedMethod: onActionReceivedMethod,
      onNotificationCreatedMethod: onNotificationCreatedMethod,
      onNotificationDisplayedMethod: onNotificationDisplayedMethod,
      onDismissActionReceivedMethod: onDismissActionReceivedMethod,
    );

    debugPrint('ReminderService initialized');
  }

  /// Use this method to detect when a new notification or a schedule is created
  @pragma("vm:entry-point")
  static Future<void> onNotificationCreatedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('Notification created');
  }

  /// Use this method to detect every time that a new notification is displayed
  @pragma("vm:entry-point")
  static Future<void> onNotificationDisplayedMethod(
    ReceivedNotification receivedNotification,
  ) async {
    debugPrint('Notification displayed');
  }

  /// Use this method to detect if the user dismissed a notification
  @pragma("vm:entry-point")
  static Future<void> onDismissActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    debugPrint('Notification dismissed');
  }

  /// Use this method to detect when the user taps on a notification or action button
  @pragma("vm:entry-point")
  static Future<void> onActionReceivedMethod(
    ReceivedAction receivedAction,
  ) async {
    // Ensure Firebase is ready for the sync calls in background isolates
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp();
      }
    } catch (e) {
      debugPrint('REMINDER_ACTION_ERROR: Firebase init failed: $e');
    }

    debugPrint('Action received: ${receivedAction.buttonKeyPressed}');

    final int? todoId = receivedAction.id;
    if (todoId == null) return;

    if (receivedAction.buttonKeyPressed == 'SNOOZE') {
      // Reschedule for 10 mins later
      debugPrint('Snoozing Todo $todoId');
      final todo = await DatabaseService.instance.readTodo(todoId);
      final newDate = DateTime.now().add(const Duration(minutes: 10));

      final updatedTodo = todo.copyWith(reminderTime: newDate);
      await DatabaseService.instance.updateTodo(updatedTodo);
      await FirestoreService.instance.syncTodo(updatedTodo);

      await ReminderService().scheduleMissionReminder(
        todo: updatedTodo,
        scheduledDate: newDate,
      );

      // Signal main isolate to refresh UI
      final SendPort? sendPort = IsolateNameServer.lookupPortByName(
        'db_refresh_port',
      );
      sendPort?.send('refresh');
    } else if (receivedAction.buttonKeyPressed == 'DONE') {
      // Mark as completed
      debugPrint('Marking Todo $todoId as done');
      final todo = await DatabaseService.instance.readTodo(todoId);
      final updatedTodo = todo.copyWith(isCompleted: true);
      await DatabaseService.instance.updateTodo(updatedTodo);
      await FirestoreService.instance.syncTodo(updatedTodo);

      // Signal main isolate to refresh UI
      final SendPort? sendPort = IsolateNameServer.lookupPortByName(
        'db_refresh_port',
      );
      sendPort?.send('refresh');
    }
  }

  Future<void> scheduleMissionReminder({
    required Todo todo,
    required DateTime scheduledDate,
  }) async {
    debugPrint(
      'REMINDER_SERVICE: Attempting to LOCAL schedule mission for "${todo.title}" at $scheduledDate',
    );

    // Still keep local schedule as secondary fallback
    try {
      await AwesomeNotifications().createNotification(
        content: NotificationContent(
          id: todo.id ?? 999,
          channelKey: 'mission_channel',
          title: '🔔 MISSION: ${todo.title}',
          body: 'Action is required. Start your focus session now!',
          notificationLayout: NotificationLayout.Default,
          category: NotificationCategory.Reminder,
          payload: {'todoId': todo.id.toString()},
          wakeUpScreen: true,
          fullScreenIntent: true,
          criticalAlert: true,
        ),
        actionButtons: _buildButtons(),
        schedule: NotificationCalendar.fromDate(date: scheduledDate),
      );
      debugPrint('REMINDER_SERVICE: Local Schedule SUCCESS for ID=${todo.id}');
    } catch (e) {
      debugPrint(
        'REMINDER_SERVICE: Local Schedule FAILED (will rely on cloud): $e',
      );
    }
  }

  /// Shows the interactive notification immediately.
  /// Used when a Cloud Message arrives.
  Future<void> showInteractiveNotification({
    required int id,
    required String title,
    required String body,
    Map<String, String?>? payload,
  }) async {
    debugPrint(
      'REMINDER_SERVICE: Showing CLOUD interactive notification for ID=$id',
    );

    await AwesomeNotifications().createNotification(
      content: NotificationContent(
        id: id,
        channelKey: 'mission_channel',
        title: '🔔 CLOUD MISSION: $title',
        body: body,
        notificationLayout: NotificationLayout.Default,
        category: NotificationCategory.Reminder,
        payload: payload,
        wakeUpScreen: true,
        fullScreenIntent: true,
        criticalAlert: true,
      ),
      actionButtons: _buildButtons(),
    );
  }

  List<NotificationActionButton> _buildButtons() {
    return [
      NotificationActionButton(
        key: 'SNOOZE',
        label: 'Snooze 10m',
        actionType: ActionType.SilentBackgroundAction,
      ),
      NotificationActionButton(
        key: 'DONE',
        label: 'Mark Done',
        actionType:
            ActionType.Default, // Bring to foreground to ensure UI refreshes
      ),
    ];
  }

  Future<void> cancelReminder(int id) async {
    await AwesomeNotifications().cancel(id);
  }
}
