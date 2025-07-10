import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_background/flutter_background.dart';
import 'package:provider/provider.dart';
import '../services/settings_service.dart';

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

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late int _totalSeconds;
  late int _currentSeconds;
  Timer? _timer;
  Timer? _blockingTimer;
  bool _isRunning = false;
  final DndService _dndService = DndService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final PermissionService _permissionService = PermissionService();

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Break Logic
  bool _isBreak = false;
  bool _autoBreakEnabled = false;

  // Permission Logic
  bool _isPermissionDialogShowing = false;
  bool _isCheckingPermissions = false;
  int _timeUntilBreak = 1800; // 30 mins
  int _currentBreakSeconds = 300; // 5 mins
  // static const int _focusInterval = 10; // Dev Mode (10s)
  // static const int _breakDuration = 5;  // Dev Mode (5s)
  static const int _focusInterval = 1800; // 30 mins
  static const int _breakDuration = 300; // 5 mins

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Pulse Animation
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 2),
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.05).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _totalSeconds = widget.durationInMinutes * 60;
    _currentSeconds = _totalSeconds;

    // Initialize Break Logic
    _timeUntilBreak = _focusInterval;
    _currentBreakSeconds = _breakDuration;

    // Check Setting
    final settings = Provider.of<SettingsService>(context, listen: false);
    _autoBreakEnabled = settings.getAutoBreak();

    _initSession();
  }

  Future<void> _initSession() async {
    await _checkPermissionsAndStart();
  }

  Future<void> _checkPermissionsAndStart() async {
    if (_isCheckingPermissions) return;
    _isCheckingPermissions = true;

    try {
      if (Platform.isAndroid) {
        // Check all permissions
        bool dndGranted = await _dndService.isPermissionGranted();
        bool usageGranted = await _permissionService.checkUsagePermission();
        bool overlayGranted = await _permissionService.checkOverlayPermission();

        if (!mounted) return;

        if (dndGranted && usageGranted && overlayGranted) {
          if (_isPermissionDialogShowing) {
            Navigator.of(context, rootNavigator: true).pop(); // Close dialog
            _isPermissionDialogShowing = false;
          }
          _startTimer();
        } else {
          if (mounted && !_isPermissionDialogShowing) {
            _showPermissionDialog(dndGranted, usageGranted, overlayGranted);
          }
        }
      } else {
        _startTimer();
      }
    } finally {
      _isCheckingPermissions = false;
    }
  }

  void _showPermissionDialog(
    bool dndGranted,
    bool usageGranted,
    bool overlayGranted,
  ) {
    String title = 'Permission Required';
    String message = '';
    VoidCallback onGrant = () {};

    if (!dndGranted) {
      title = 'Do Not Disturb Access';
      message =
          'FocusFlow needs Do Not Disturb access to silence notifications during your session.';
      onGrant = () async {
        await _dndService.requestPermission();
      };
    } else if (!usageGranted) {
      title = 'Usage Access';
      message = 'FocusFlow needs Usage Access to detect if you open apps.';
      onGrant = () async {
        await _permissionService.requestUsagePermission();
      };
    } else if (!overlayGranted) {
      title = 'Overlay Permission';
      message = 'FocusFlow needs Overlay permission to block apps.';
      onGrant = () async {
        await _permissionService.requestOverlayPermission();
      };
    }

    _isPermissionDialogShowing = true;
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () {
              // We rely on lifecycle resume to close dialog if granted?
              // Or if user cancels?
              // If user clicks "Grant", we close dialog AND run action.
              // If we close dialog here, _isPermissionDialogShowing becomes false?
              // But we want to keep it "true" regarding logic until we re-check?
              // No, if we close it, we flip flag.
              Navigator.pop(context);
              _isPermissionDialogShowing = false;
              onGrant();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    ).then((_) {
      // Cleanup if dialog closed via other means (e.g. back button if we allowed it, but barrier is false)
      _isPermissionDialogShowing = false;
    });
  }


  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _blockingTimer?.cancel();
    _pulseController.dispose();
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
      _pulseController.repeat(reverse: true);
    });

    // Main Countdown Timer
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_isBreak) {
          // Break Logic
          if (_currentBreakSeconds > 0) {
            _currentBreakSeconds--;
          } else {
            _endBreak();
          }
        } else {
          // Focus Logic
          if (_currentSeconds > 0) {
            _currentSeconds--;

            // Check for Break Interval
            if (_autoBreakEnabled) {
              if (_timeUntilBreak > 0) {
                _timeUntilBreak--;
              } else {
                _startBreak();
              }
            }
          } else {
            _finishSession();
          }
        }
      });
    });

    // App Blocking Monitor
    if (widget.selectedApps.isNotEmpty && Platform.isAndroid) {
      _blockingTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        if (!_isRunning || _isBreak) return; // Don't block during break
        await _checkForegroundApp();
      });
    }
  }

  void _startBreak() {
    _isBreak = true;
    _currentBreakSeconds = _breakDuration;
    _safeTurnOffDnd(); // Relax DND
    FlutterRingtonePlayer().playNotification(); // Sound
    // Pulse faster or different color? Changing UI is enough.
  }

  void _endBreak() {
    _isBreak = false;
    _timeUntilBreak = _focusInterval; // Reset interval

    FlutterRingtonePlayer().playNotification(); // Sound (Before DND)

    // Re-enable DND if Focus is running
    _dndService.turnOnDnd().catchError((e) {
      debugPrint('Error re-enabling DND: $e');
    });
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
      _pulseController.stop();
      _pulseController.value = 0; // Reset
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
      _pulseController.stop();
    });

    FlutterRingtonePlayer().playNotification(); // Sound

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
        builder: (context) => Dialog(
          backgroundColor: Colors.transparent,
          elevation: 0,
          child: Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: Theme.of(context).brightness == Brightness.dark
                    ? [const Color(0xFF1A1A2E), const Color(0xFF16213E)]
                    : [Colors.white, const Color(0xFFF0F2F5)],
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.check_circle_rounded,
                    color: Colors.greenAccent,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Session Complete!',
                  style: GoogleFonts.outfit(
                    fontSize: 24,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white
                        : Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Great job focusing! You are one step closer to your goals.',
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    fontSize: 16,
                    color: Theme.of(context).brightness == Brightness.dark
                        ? Colors.white60
                        : Colors.black54,
                  ),
                ),
                const SizedBox(height: 24),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop(); // Close dialog
                      Navigator.of(
                        context,
                      ).popUntil((route) => route.isFirst); // Back to Home
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.white
                          : Colors.black,
                      foregroundColor:
                          Theme.of(context).brightness == Brightness.dark
                          ? Colors.black
                          : Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 0,
                    ),
                    child: Text(
                      'Continue',
                      style: GoogleFonts.outfit(
                        fontWeight: FontWeight.bold,
                        fontSize: 16,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
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
    final secondsToDisplay = _isBreak ? _currentBreakSeconds : _currentSeconds;
    final minutes = (secondsToDisplay ~/ 60).toString().padLeft(2, '0');
    final seconds = (secondsToDisplay % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _percent {
    if (_isBreak) {
      return 1.0 - (_currentBreakSeconds / _breakDuration);
    }
    if (_totalSeconds == 0) return 0.0;
    return 1.0 - (_currentSeconds / _totalSeconds);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Subtle Mesh Gradient Background
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E), // Dark Blue
                    const Color(0xFF16213E), // Slightly lighter
                    const Color(0xFF0F3460), // Accent hint
                  ]
                : [
                    const Color(0xFFF0F2F5), // Soft white/grey
                    const Color(0xFFE6E6FA), // Lavender hint
                    const Color(0xFFE0FFFF), // Cyan hint
                  ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // 1. Header with Glass Pill
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 24,
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    IconButton(
                      onPressed: () => Navigator.pop(context),
                      icon: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isDark
                              ? Colors.white10
                              : Colors.black.withOpacity(0.05),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.keyboard_arrow_down,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.white.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: isDark
                              ? Colors.white12
                              : Colors.black.withOpacity(0.05),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.local_fire_department,
                            size: 16,
                            color: isDark ? Colors.orangeAccent : Colors.orange,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            widget.category.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              fontSize: 14,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 48), // Balance centering
                  ],
                ),
              ),

              const Spacer(),

              // 2. Timer with Breathing Animation
              AnimatedBuilder(
                animation: _pulseAnimation,
                builder: (context, child) {
                  return Transform.scale(
                    scale: _isRunning ? _pulseAnimation.value : 1.0,
                    child: CircularPercentIndicator(
                      radius: 140.0,
                      lineWidth: 15.0, // Thicker line
                      percent: _percent.clamp(0.0, 1.0),
                      circularStrokeCap: CircularStrokeCap.round,
                      backgroundColor: isDark
                          ? Colors.white.withOpacity(0.05)
                          : Colors.grey.withOpacity(0.1),
                      progressColor: _isBreak
                          ? Colors.greenAccent
                          : _getCategoryColor(widget.category), // Dynamic color
                      center: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            _formattedTime,
                            style: GoogleFonts.spaceMono(
                              // Monospace for numbers
                              fontSize: 64,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _isBreak
                                ? 'TAKE A BREAK'
                                : (_isRunning ? 'FOCUSING' : 'PAUSED'),
                            style: GoogleFonts.outfit(
                              fontSize: 14,
                              letterSpacing: 2,
                              color: isDark ? Colors.white54 : Colors.black45,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),

              const Spacer(),

              // 3. Modern Controls
              Padding(
                padding: const EdgeInsets.all(32.0),
                child: Column(
                  children: [
                    // Play/Pause Button
                    GestureDetector(
                      onTap: _toggleTimer,
                      child: Container(
                        height: 80,
                        width: 80,
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white : Colors.black,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: (isDark ? Colors.white : Colors.black)
                                  .withOpacity(0.3),
                              blurRadius: 20,
                              spreadRadius: 5,
                            ),
                          ],
                        ),
                        child: Icon(
                          _isRunning
                              ? Icons.pause_rounded
                              : Icons.play_arrow_rounded,
                          size: 40,
                          color: isDark ? Colors.black : Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 40),

                    // Finish Early / Stop
                    TextButton(
                      onPressed: _finishSession,
                      style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 24,
                          vertical: 12,
                        ),
                        backgroundColor: isDark
                            ? Colors.white.withOpacity(0.05)
                            : Colors.grey.withOpacity(0.1),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(30),
                        ),
                      ),
                      child: Text(
                        'Finish Session',
                        style: GoogleFonts.outfit(
                          color: isDark ? Colors.white54 : Colors.black54,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Helper for dynamic colors
  Color _getCategoryColor(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return const Color(0xFF4481EB);
      case 'personal':
        return const Color(0xFF9F44D3);
      case 'reading':
        return const Color(0xFFFF9A44);
      case 'sleep':
        return const Color(0xFF4A148C);
      default:
        return const Color(0xFF6C63FF);
    }
  }
}
