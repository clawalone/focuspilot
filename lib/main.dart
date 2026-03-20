import 'dart:io';
import 'dart:ui';
import 'dart:isolate';
import 'package:flutter/material.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'theme/app_theme.dart';
import 'screens/home_screen.dart';

import 'package:provider/provider.dart';
import 'services/settings_service.dart';
import 'services/reminder_service.dart'; // Added this import
import 'services/app_service.dart';

import 'package:firebase_core/firebase_core.dart';
import 'services/auth_service.dart';
import 'services/database_service.dart';
import 'screens/login_screen.dart';
import 'services/notification_service.dart';
import 'package:android_alarm_manager_plus/android_alarm_manager_plus.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'services/firestore_service.dart';

@pragma("vm:entry-point")
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  debugPrint("FCM_BACK: Handling background message: ${message.messageId}");

  // Extract data and show notification via ReminderService
  final data = message.data;
  if (data.containsKey('todoId')) {
    await ReminderService().showInteractiveNotification(
      id: int.tryParse(data['todoId'].toString()) ?? 9991,
      title: data['title'] ?? 'Mission Alert',
      body: data['body'] ?? 'Action is required.',
      payload: Map<String, String?>.from(data),
    );
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Setup cross-isolate communication for DB refresh
  final ReceivePort receivePort = ReceivePort();
  IsolateNameServer.registerPortWithName(
    receivePort.sendPort,
    'db_refresh_port',
  );
  receivePort.listen((message) {
    debugPrint('ISOLATE_SIGNAL: Database refresh requested');
    DatabaseService.instance.changeNotifier.value++;
  });

  // Initialize Alarms
  if (Platform.isAndroid) {
    await AndroidAlarmManager.initialize();
  }

  // Initialize Notifications
  try {
    await NotificationService().init();
  } catch (e) {
    debugPrint('Notification initialization failed: $e');
  }

  try {
    await Firebase.initializeApp();

    // Set background handler
    FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);

    // Request permissions for iOS/Android 13+
    FirebaseMessaging messaging = FirebaseMessaging.instance;
    await messaging.requestPermission(alert: true, badge: true, sound: true);

    // Update Token for this user
    await FirestoreService.instance.updateDeviceToken();

    // Foreground listener
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      debugPrint("FCM_FORE: Message received: ${message.messageId}");
      final data = message.data;
      if (data.containsKey('todoId')) {
        ReminderService().showInteractiveNotification(
          id: int.tryParse(data['todoId'].toString()) ?? 9991,
          title: data['title'] ?? 'Mission Alert',
          body: data['body'] ?? 'Action is required.',
          payload: Map<String, String?>.from(data),
        );
      }
    });
  } catch (e) {
    debugPrint('Firebase initialization failed: $e');
  }

  if (Platform.isAndroid || Platform.isIOS) {
    // Only init background for mobile
    // ... though actually we use flutter_background which might check internally
  }

  if (Platform.isWindows || Platform.isLinux || Platform.isMacOS) {
    // Initialize FFI
    sqfliteFfiInit();
    databaseFactory = databaseFactoryFfi;
  }

  // Initialize Settings
  final settings = await SettingsService.init();
  themeNotifier.value = settings.getThemeMode();

  // Initialize Reminder Service (Includes Awesome Notifications)
  try {
    await ReminderService().initialize();
  } catch (e) {
    debugPrint('ReminderService initialization failed: $e');
  }

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider.value(value: settings),
        ChangeNotifierProvider(create: (_) => AppService()),
        ChangeNotifierProvider(create: (_) => AuthService()),
      ],
      child: const MindFluxApp(),
    ),
  );
}

// Global navigator key
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// Global theme notifier
final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.system);

class MindFluxApp extends StatelessWidget {
  const MindFluxApp({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = Provider.of<AuthService>(context);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (context, currentMode, child) {
        return MaterialApp(
          navigatorKey: navigatorKey,
          title: 'MindFlux',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentMode,
          home: StreamBuilder(
            stream: authService.authStateChanges,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Scaffold(
                  body: Center(child: CircularProgressIndicator()),
                );
              }
              if (snapshot.hasData) {
                return const HomeScreen();
              }
              return const LoginScreen();
            },
          ),
        );
      },
    );
  }
}
