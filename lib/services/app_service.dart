import 'package:flutter/material.dart';
import 'package:installed_apps/app_info.dart';
import 'package:installed_apps/installed_apps.dart';

class AppService extends ChangeNotifier {
  List<AppInfo> _socialApps = [];
  List<AppInfo> _messengerApps = [];
  List<AppInfo> _otherApps = [];
  bool _isLoading = false;
  bool _isLoaded = false;

  List<AppInfo> get socialApps => _socialApps;
  List<AppInfo> get messengerApps => _messengerApps;
  List<AppInfo> get otherApps => _otherApps;
  bool get isLoading => _isLoading;
  bool get isLoaded => _isLoaded;

  // Known package names for categorization
  final List<String> _socialPackages = [
    'com.facebook.katana',
    'com.instagram.android',
    'com.zhiliaoapp.musically', // TikTok
    'com.twitter.android',
    'com.snapchat.android',
    'com.pinterest',
    'com.linkedin.android',
  ];

  final List<String> _messengerPackages = [
    'org.telegram.messenger',
    'com.whatsapp',
    'com.discord',
    'com.viber.voip',
    'com.facebook.orca', // Messenger
    'com.google.android.apps.messaging',
    'com.skype.raider',
  ];

  Future<void> loadApps() async {
    if (_isLoading || _isLoaded) return;

    _isLoading = true;
    notifyListeners();

    try {
      List<AppInfo> apps = await InstalledApps.getInstalledApps(true, true);

      List<AppInfo> social = [];
      List<AppInfo> messengers = [];
      List<AppInfo> others = [];

      for (var app in apps) {
        final packageName = app.packageName.toLowerCase();

        // Filter system junk
        if (packageName.contains('com.android.providers') ||
            packageName.contains('com.android.vpndialogs') ||
            packageName.contains('com.android.wallpaper') ||
            packageName.contains('com.google.android.overlay') ||
            packageName.contains('android.auto_generated') ||
            packageName.contains('com.example.focusflow') ||
            packageName.contains('com.focuspilot.app')) {
          continue;
        }

        if (_socialPackages.any((p) => packageName.contains(p))) {
          social.add(app);
        } else if (_messengerPackages.any((p) => packageName.contains(p))) {
          messengers.add(app);
        } else {
          others.add(app);
        }
      }

      // Sort
      social.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      messengers.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );
      others.sort(
        (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
      );

      _socialApps = social;
      _messengerApps = messengers;
      _otherApps = others;
      _isLoaded = true;
    } catch (e) {
      debugPrint('Error loading apps: $e');
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }
}
