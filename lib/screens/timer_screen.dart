import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_background/flutter_background.dart';

import '../theme/app_theme.dart';
import '../services/dnd_service.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../models/session.dart';

class TimerScreen extends StatefulWidget {
  final String category;
  final int durationInMinutes;
  final List<String> selectedApps;

  const TimerScreen({
    super.key,
    this.category = 'Focus',
    this.durationInMinutes = 25,
    this.selectedApps = const [],
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen> with WidgetsBindingObserver {
  late int _totalSeconds;
  late int _currentSeconds;
  Timer? _timer;
  Timer? _blockingTimer;
  bool _isRunning = false;
  final DndService _dndService = DndService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final PermissionService _permissionService = PermissionService();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _totalSeconds = widget.durationInMinutes * 60;
    _currentSeconds = _totalSeconds;
    _initSession();
  }

  Future<void> _initSession() async {
    await _initDnd();
    await _checkPermissionsAndStart();
  }

  Future<void> _checkPermissionsAndStart() async {
    if (Platform.isAndroid) {
      bool usageGranted = await _permissionService.checkUsagePermission();
      bool overlayGranted = await _permissionService.checkOverlayPermission();

      if (usageGranted && overlayGranted) {
        _startTimer();
      } else {
        if (mounted) {
          _showPermissionDialog(usageGranted, overlayGranted);
        }
      }
    } else {
      _startTimer();
    }
  }

  void _showPermissionDialog(bool usageGranted, bool overlayGranted) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('Permissions Required'),
        content: Text(
          !usageGranted
              ? 'FocusFlow needs Usage Access to detect apps.'
              : 'FocusFlow needs "Display over other apps" permission to block apps effectively.',
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              if (!usageGranted) {
                await _permissionService.requestUsagePermission();
              } else if (!overlayGranted) {
                await _permissionService.requestOverlayPermission();
              }
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    );
  }

  Future<void> _initDnd() async {
    try {
      await _dndService.requestPermission();
    } catch (e) {
      debugPrint('Error requesting DND permission: $e');
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _blockingTimer?.cancel();
    _safeTurnOffDnd();
    super.dispose();
  }

  Future<void> _safeTurnOffDnd() async {
    try {
      await _dndService.turnOffDnd();
    } catch (e) {
      debugPrint('Error turning off DND: $e');
    }
  }

  Future<void> _enableBackgroundExecution() async {
    try {
      const androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: 'Focus Session Running',
        notificationText: 'FocusFlow is keeping you on track.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      );
      bool success = await FlutterBackground.initialize(
        androidConfig: androidConfig,
      );
      if (success) {
        await FlutterBackground.enableBackgroundExecution();
      }
    } catch (e) {
      debugPrint('Error enabling background execution: $e');
    }
  }

  Future<void> _disableBackgroundExecution() async {
    try {
      if (FlutterBackground.isBackgroundExecutionEnabled) {
        await FlutterBackground.disableBackgroundExecution();
      }
    } catch (e) {
      debugPrint('Error disabling background execution: $e');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Check permissions again when user returns to app
      if (!_isRunning && _timer == null) {
        _checkPermissionsAndStart();
      }
    }
  }

  void _startTimer() {
    if (_timer != null) return;

    // Fire and forget DND
    _dndService.turnOnDnd().catchError((e) {
      debugPrint('Error turning on DND: $e');
    });

    // Enable background execution
    _enableBackgroundExecution();

    setState(() {
      _isRunning = true;
    });

    // Main Countdown Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else {
          _finishSession();
        }
      });
    });

    // App Blocking Monitor
    if (widget.selectedApps.isNotEmpty && Platform.isAndroid) {
      _blockingTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        if (!_isRunning) return;
        await _checkForegroundApp();
      });
    }
  }

  Future<void> _checkForegroundApp() async {
    try {
      final currentPackage = await _permissionService.getForegroundApp();

      if (currentPackage != null) {
        // Check if current app is in blocked list
        if (widget.selectedApps.contains(currentPackage)) {
          debugPrint('Blocked app detected: $currentPackage');
          await _permissionService.bringAppToFront();
        }
      }
    } catch (e) {
      debugPrint('Error checking foreground app: $e');
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _blockingTimer?.cancel(); // Stop blocking while paused
    _safeTurnOffDnd();
    _disableBackgroundExecution();
    setState(() {
      _isRunning = false;
    });
  }

  void _finishSession() async {
    _timer?.cancel();
    _timer = null;
    _blockingTimer?.cancel();
    _safeTurnOffDnd();
    _disableBackgroundExecution();
    setState(() {
      _isRunning = false;
    });

    // Save session
    try {
      final session = Session(
        category: widget.category,
        duration: widget.durationInMinutes * 60 - _currentSeconds,
        timestamp: DateTime.now(),
        appsLimitedCount: widget.selectedApps.length,
      );
      await _databaseService.create(session);
      debugPrint('Session saved successfully: ${session.toMap()}');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }

    if (mounted) {
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Session Complete!'),
          content: const Text('Great job focusing!'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop(); // Close dialog
                Navigator.of(context).pop(); // Go back to home
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _toggleTimer() {
    if (_isRunning) {
      _pauseTimer();
    } else {
      _startTimer();
    }
  }

  String get _formattedTime {
    final minutes = (_currentSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_currentSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _percent {
    if (_totalSeconds == 0) return 0.0;
    return 1.0 - (_currentSeconds / _totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            children: [
              // Header
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const SizedBox(width: 40), // Balance for close button
                  Text(
                    widget.category,
                    style: Theme.of(context).textTheme.displayMedium,
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),
              const Spacer(),

              // Timer
              CircularPercentIndicator(
                radius: 140.0,
                lineWidth: 10.0,
                percent: _percent.clamp(0.0, 1.0),
                center: Text(
                  _formattedTime,
                  style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 64,
                    fontWeight: FontWeight.w300,
                  ),
                ),
                progressColor: AppTheme.primaryColor,
                backgroundColor: Colors.grey.shade200,
                circularStrokeCap: CircularStrokeCap.round,
                animation: true,
                animateFromLastPercent: true,
              ),

              const Spacer(),

              // Break/Start Button
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: _toggleTimer,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.black,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: Text(
                    _isRunning ? 'break' : 'start',
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 16),
              TextButton(
                onPressed: _finishSession,
                child: const Text(
                  'finish early',
                  style: TextStyle(
                    fontSize: 16,
                    color: Colors.grey,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
              const SizedBox(height: 24),
            ],
          ),
        ),
      ),
    );
  }
}
