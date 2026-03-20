import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:flutter_ringtone_player/flutter_ringtone_player.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';
import 'package:flutter_background/flutter_background.dart';

import 'package:provider/provider.dart';
import '../services/settings_service.dart';
import '../services/dnd_service.dart';
import '../services/database_service.dart';
import '../services/permission_service.dart';
import '../services/notification_service.dart';
import '../models/session.dart';

enum TimerPhase { revise, work, breakTime }

class TimerStep {
  final TimerPhase phase;
  final int durationSeconds;
  final String label;

  TimerStep({
    required this.phase,
    required this.durationSeconds,
    required this.label,
  });
}

class TimerScreen extends StatefulWidget {
  final String category;
  final int workMinutes;
  final int reviseMinutes;
  final int breakMinutes;
  final int sessionsCount;
  final bool isReviseBefore;
  final String? note;
  final List<String> selectedApps;

  const TimerScreen({
    super.key,
    this.category = 'Focus',
    this.workMinutes = 25,
    this.reviseMinutes = 10,
    this.breakMinutes = 5,
    this.sessionsCount = 1,
    this.isReviseBefore = true,
    this.note,
    this.selectedApps = const [],
  });

  @override
  State<TimerScreen> createState() => _TimerScreenState();
}

class _TimerScreenState extends State<TimerScreen>
    with TickerProviderStateMixin, WidgetsBindingObserver {
  late List<TimerStep> _steps;
  int _currentStepIndex = 0;
  late int _currentSeconds;

  Timer? _timer;
  Timer? _blockingTimer;
  bool _isRunning = false;
  bool _isSessionCompleted = false;
  final DndService _dndService = DndService();
  final DatabaseService _databaseService = DatabaseService.instance;
  final PermissionService _permissionService = PermissionService();
  final NotificationService _notificationService = NotificationService();

  // Animation
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  // Permission Logic
  bool _isPermissionDialogShowing = false;
  bool _isCheckingPermissions = false;

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

    _initSteps();
    _currentSeconds = _steps[_currentStepIndex].durationSeconds;

    _initSession();
  }

  void _initSteps() {
    _steps = [];

    // 1. Revision Before
    if (widget.isReviseBefore && widget.reviseMinutes > 0) {
      _steps.add(
        TimerStep(
          phase: TimerPhase.revise,
          durationSeconds: widget.reviseMinutes * 60,
          label: 'REVISE',
        ),
      );
    }

    // 2. Work & Break Cycles
    for (int i = 0; i < widget.sessionsCount; i++) {
      _steps.add(
        TimerStep(
          phase: TimerPhase.work,
          durationSeconds: widget.workMinutes * 60,
          label: 'WORK ${i + 1}/${widget.sessionsCount}',
        ),
      );

      if (i < widget.sessionsCount - 1 && widget.breakMinutes > 0) {
        _steps.add(
          TimerStep(
            phase: TimerPhase.breakTime,
            durationSeconds: widget.breakMinutes * 60,
            label: 'BREAK',
          ),
        );
      }
    }

    // 3. Revision After
    if (!widget.isReviseBefore && widget.reviseMinutes > 0) {
      _steps.add(
        TimerStep(
          phase: TimerPhase.revise,
          durationSeconds: widget.reviseMinutes * 60,
          label: 'REVISE',
        ),
      );
    }

    if (_steps.isEmpty) {
      // Fallback
      _steps.add(
        TimerStep(
          phase: TimerPhase.work,
          durationSeconds: widget.workMinutes * 60,
          label: 'WORK',
        ),
      );
    }
  }

  Future<void> _initSession() async {
    await _checkPermissionsAndStart();
  }

  Future<void> _checkPermissionsAndStart() async {
    if (_isCheckingPermissions) return;
    _isCheckingPermissions = true;

    try {
      if (Platform.isAndroid) {
        bool dndGranted = await _dndService.isPermissionGranted();
        bool usageGranted = await _permissionService.checkUsagePermission();
        bool overlayGranted = await _permissionService.checkOverlayPermission();

        if (!mounted) return;

        if (dndGranted && usageGranted && overlayGranted) {
          if (_isPermissionDialogShowing) {
            Navigator.of(context, rootNavigator: true).pop();
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
          'MindFlux needs Do Not Disturb access to silence notifications.';
      onGrant = () async => await _dndService.requestPermission();
    } else if (!usageGranted) {
      title = 'Usage Access';
      message = 'MindFlux needs Usage Access to detect if you open apps.';
      onGrant = () async => await _permissionService.requestUsagePermission();
    } else if (!overlayGranted) {
      title = 'Overlay Permission';
      message = 'MindFlux needs Overlay permission to block apps.';
      onGrant = () async => await _permissionService.requestOverlayPermission();
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
              Navigator.pop(context);
              _isPermissionDialogShowing = false;
              onGrant();
            },
            child: const Text('Grant Permission'),
          ),
        ],
      ),
    ).then((_) => _isPermissionDialogShowing = false);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _timer?.cancel();
    _blockingTimer?.cancel();
    _pulseController.dispose();
    _permissionService.removeOverlay();
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

  Future<void> _safeTurnOnDnd() async {
    final settings = Provider.of<SettingsService>(context, listen: false);
    if (!settings.getDndEnabled()) return;

    try {
      await _dndService.turnOnDnd();
    } catch (e) {
      debugPrint('Error turning on DND: $e');
    }
  }

  Future<void> _enableBackgroundExecution() async {
    try {
      const androidConfig = FlutterBackgroundAndroidConfig(
        notificationTitle: 'Focus Session Running',
        notificationText: 'MindFlux is keeping you on track.',
        notificationImportance: AndroidNotificationImportance.normal,
        notificationIcon: AndroidResource(
          name: 'ic_launcher',
          defType: 'mipmap',
        ),
      );
      if (await FlutterBackground.initialize(androidConfig: androidConfig)) {
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
      _permissionService.removeOverlay();
      if (!_isRunning && !_isSessionCompleted && _timer == null) {
        _checkPermissionsAndStart();
      }
    }
  }

  void _startTimer() {
    if (_timer != null) return;

    _safeTurnOnDnd();
    _enableBackgroundExecution();

    setState(() {
      _isRunning = true;
      _pulseController.repeat(reverse: true);
    });

    _schedulePhaseNotification();

    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      setState(() {
        if (_currentSeconds > 0) {
          _currentSeconds--;
        } else {
          _nextStep();
        }
      });
    });

    if (widget.selectedApps.isNotEmpty && Platform.isAndroid) {
      _blockingTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) async {
        if (!_isRunning ||
            _steps[_currentStepIndex].phase == TimerPhase.breakTime)
          return;
        await _checkForegroundApp();
      });
    }
  }

  void _nextStep() {
    if (_currentStepIndex < _steps.length - 1) {
      _currentStepIndex++;
      _currentSeconds = _steps[_currentStepIndex].durationSeconds;
      FlutterRingtonePlayer().playNotification();

      // Notify user of next phase
      _notificationService.showNotification(
        id: 10001,
        title:
            '${_steps[_currentStepIndex].label == "BREAK" ? "Time for a Break!" : "Focus Time!"}',
        body: '${_steps[_currentStepIndex].label} started.',
      );

      // Manage DND based on phase
      if (_steps[_currentStepIndex].phase == TimerPhase.breakTime) {
        _safeTurnOffDnd();
      } else {
        _safeTurnOnDnd();
      }
      _schedulePhaseNotification();
    } else {
      _finishSession();
    }
  }

  void _schedulePhaseNotification() {
    final step = _steps[_currentStepIndex];
    _notificationService.scheduleNotification(
      id: 10001, // Fixed ID for timer alerts
      title: 'Time is up!',
      body: '${step.label} session is complete.',
      scheduledDate: DateTime.now().add(Duration(seconds: _currentSeconds)),
    );
  }

  Future<void> _checkForegroundApp() async {
    try {
      final currentPackage = await _permissionService.getForegroundApp();
      if (currentPackage != null &&
          widget.selectedApps.contains(currentPackage)) {
        await _permissionService.bringAppToFront();
      }
    } catch (e) {
      debugPrint('Error checking foreground app: $e');
    }
  }

  void _pauseTimer() {
    _timer?.cancel();
    _timer = null;
    _blockingTimer?.cancel();
    _safeTurnOffDnd();
    _disableBackgroundExecution();
    _notificationService.cancelNotification(10001);
    _permissionService.removeOverlay();
    setState(() {
      _isRunning = false;
      _pulseController.stop();
      _pulseController.value = 0;
    });
  }

  Future<void> _saveSession() async {
    try {
      int focusSecondsSpent = 0;
      for (int i = 0; i <= _currentStepIndex; i++) {
        int secondsInStep = (i == _currentStepIndex)
            ? (_steps[i].durationSeconds - _currentSeconds)
            : _steps[i].durationSeconds;

        if (_steps[i].phase != TimerPhase.breakTime) {
          focusSecondsSpent += secondsInStep;
        }
      }

      final session = Session(
        category: widget.category,
        duration: focusSecondsSpent,
        timestamp: DateTime.now(),
        appsLimitedCount: widget.selectedApps.length,
        workDuration: widget.workMinutes * 60,
        reviseDuration: widget.reviseMinutes * 60,
        breakDuration: widget.breakMinutes * 60,
        sessionsCount: widget.sessionsCount,
        isReviseBefore: widget.isReviseBefore,
        note: widget.note,
      );
      await _databaseService.create(session);
      debugPrint('Session saved: ${session.toMap()}');
    } catch (e) {
      debugPrint('Error saving session: $e');
    }
  }

  void _finishSession() async {
    _timer?.cancel();
    _timer = null;
    _blockingTimer?.cancel();
    _blockingTimer = null; // reset to null
    _safeTurnOffDnd();
    _disableBackgroundExecution();
    _notificationService.cancelNotification(10001);
    _permissionService.removeOverlay();
    setState(() {
      _isRunning = false;
      _isSessionCompleted = true;
      _pulseController.stop();
    });

    FlutterRingtonePlayer().playNotification();

    // Explicit notification for session complete
    _notificationService.showNotification(
      id: 10001,
      title: 'Session Complete!',
      body: 'Great job! You have completed your focus session.',
    );

    await _saveSession();
    _permissionService.bringAppToFront();

    if (mounted) {
      _showSuccessDialog();
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: Colors.transparent,
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1E272E),
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(
                Icons.check_circle_rounded,
                color: Colors.greenAccent,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                'Session Complete!',
                style: GoogleFonts.outfit(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                'Great job focusing!',
                style: GoogleFonts.outfit(fontSize: 16, color: Colors.white70),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    Navigator.of(context).popUntil((route) => route.isFirst);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF00BCD4),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: const Text('Continue'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _toggleTimer() {
    if (_isRunning)
      _pauseTimer();
    else
      _startTimer();
  }

  void _handleBack() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: const Color(0xFF1E272E),
        title: Text(
          'Exit Timer?',
          style: GoogleFonts.outfit(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Text(
          'Do you want to save the current progress?',
          style: GoogleFonts.outfit(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => {Navigator.pop(context), Navigator.pop(context)},
            child: const Text('No', style: TextStyle(color: Colors.redAccent)),
          ),
          TextButton(
            onPressed: () async {
              await _saveSession();
              Navigator.pop(context);
              Navigator.pop(context);
            },
            child: const Text(
              'Yes',
              style: TextStyle(color: Color(0xFF00BCD4)),
            ),
          ),
        ],
      ),
    );
  }

  String get _formattedTime {
    final minutes = (_currentSeconds ~/ 60).toString().padLeft(2, '0');
    final seconds = (_currentSeconds % 60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  double get _percent {
    final total = _steps[_currentStepIndex].durationSeconds;
    if (total == 0) return 0.0;
    return 1.0 - (_currentSeconds / total);
  }

  @override
  Widget build(BuildContext context) {
    final currentStep = _steps[_currentStepIndex];

    return PopScope(
      canPop: false,
      child: Scaffold(
        backgroundColor: AppTheme.statsDarkBackground,
        body: Stack(
          children: [
            // Base Background
            Container(color: AppTheme.statsDarkBackground),

            // Background Blobs (Mesh Gradient)
            Positioned(
              top: -100,
              right: -100,
              child:
                  Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.4),
                              AppTheme.primaryColor.withOpacity(0),
                            ],
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .move(
                        begin: const Offset(0, 0),
                        end: const Offset(-50, 40),
                        duration: 10.seconds,
                        curve: Curves.easeInOut,
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.2, 1.2),
                        duration: 12.seconds,
                        curve: Curves.easeInOut,
                      ),
            ),
            Positioned(
              bottom: -100,
              left: -100,
              child:
                  Container(
                        width: 400,
                        height: 400,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.secondaryColor.withOpacity(0.3),
                              AppTheme.secondaryColor.withOpacity(0),
                            ],
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .move(
                        begin: const Offset(0, 0),
                        end: const Offset(40, -50),
                        duration: 12.seconds,
                        curve: Curves.easeInOut,
                      )
                      .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: 14.seconds,
                        curve: Curves.easeInOut,
                      ),
            ),
            Positioned(
              top: 200,
              left: -150,
              child:
                  Container(
                        width: 350,
                        height: 350,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              AppTheme.primaryColor.withOpacity(0.2),
                              AppTheme.primaryColor.withOpacity(0),
                            ],
                          ),
                        ),
                      )
                      .animate(onPlay: (c) => c.repeat(reverse: true))
                      .move(
                        begin: const Offset(0, 0),
                        end: const Offset(30, 30),
                        duration: 15.seconds,
                        curve: Curves.easeInOut,
                      ),
            ),

            // Main Content
            SafeArea(
              child: Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: _handleBack,
                          icon: const Icon(
                            Icons.keyboard_arrow_down,
                            color: Colors.white70,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 16,
                            vertical: 8,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.05),
                            borderRadius: BorderRadius.circular(20),
                            border: Border.all(color: Colors.white12),
                          ),
                          child: Text(
                            widget.category.toUpperCase(),
                            style: GoogleFonts.outfit(
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.2,
                              color: Colors.white70,
                            ),
                          ),
                        ),
                        const SizedBox(width: 48),
                      ],
                    ),
                  ),
                  const Spacer(),
                  AnimatedBuilder(
                    animation: _pulseAnimation,
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _isRunning ? _pulseAnimation.value : 1.0,
                        child: CircularPercentIndicator(
                          radius: 140.0,
                          lineWidth: 15.0,
                          percent: _percent.clamp(0.0, 1.0),
                          circularStrokeCap: CircularStrokeCap.round,
                          backgroundColor: Colors.white.withOpacity(0.05),
                          progressColor:
                              currentStep.phase == TimerPhase.breakTime
                              ? AppTheme.secondaryColor
                              : AppTheme.primaryColor,
                          center: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Text(
                                _formattedTime,
                                style: GoogleFonts.outfit(
                                  fontSize: 64,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                currentStep.label,
                                style: GoogleFonts.outfit(
                                  fontSize: 14,
                                  letterSpacing: 2,
                                  color: Colors.white54,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
                  if (widget.note != null && widget.note!.isNotEmpty) ...[
                    const SizedBox(height: 32),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 48),
                      child: Text(
                        widget.note!,
                        textAlign: TextAlign.center,
                        style: GoogleFonts.outfit(
                          color: Colors.white38,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    ),
                  ],
                  const Spacer(),
                  Padding(
                    padding: const EdgeInsets.all(32.0),
                    child: Column(
                      children: [
                        GestureDetector(
                          onTap: _toggleTimer,
                          child: Container(
                            height: 80,
                            width: 80,
                            decoration: BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.2),
                                  blurRadius: 20,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Icon(
                              _isRunning
                                  ? Icons.pause_rounded
                                  : Icons.play_arrow_rounded,
                              size: 40,
                              color: Colors.black,
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                        TextButton(
                          onPressed: _finishSession,
                          child: Text(
                            'Finish Session',
                            style: GoogleFonts.outfit(color: Colors.white38),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
