import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'dart:ui';
import 'package:tutorial_coach_mark/tutorial_coach_mark.dart';
import '../theme/app_theme.dart';
import '../models/session.dart';
import '../models/todo.dart';
import '../models/badge_data.dart';
import 'create_plan_screen.dart';
import '../services/database_service.dart';
import 'stats_screen.dart';
import 'settings_screen.dart';
import '../widgets/home_header.dart';
import '../widgets/daily_progress_card.dart';
import '../services/onboarding_service.dart';
import '../widgets/premium_tutorial_card.dart';
import '../widgets/quick_tasks_card.dart';
import '../widgets/last_session_card.dart';
import 'todo_list_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // Global Keys for Tutorial Targets
  final GlobalKey _headerKey = GlobalKey();
  final GlobalKey _calendarKey = GlobalKey(); // Key for Calendar Pill
  final GlobalKey _dailyCardKey = GlobalKey();
  final GlobalKey _startSessionKey = GlobalKey();
  final GlobalKey _tasksTabKey = GlobalKey(); // Key for Tasks Tab
  final GlobalKey _statsTabKey = GlobalKey();
  final GlobalKey _settingsTabKey = GlobalKey();

  // State
  Session? _lastSession;
  int _dailyMinutes = 0;
  int _streak = 0;
  List<BadgeData> _badges = [];
  List<Todo> _topTasks = [];
  bool _isLoading = true;

  late TutorialCoachMark _tutorialCoachMark;

  @override
  void initState() {
    super.initState();
    _loadData();
    _checkAndShowTutorial();
  }

  Future<void> _loadData() async {
    // Load Last Session
    final session = await DatabaseService.instance.getLastSession();

    // Load Daily Minutes
    final today = DateTime.now();
    final sessions = await DatabaseService.instance.readSessionsForDate(today);
    int totalSeconds = 0;
    for (var s in sessions) {
      totalSeconds += s.duration;
    }
    final minutes = totalSeconds ~/ 60;

    // Calculate total minutes for badges logic (simplified, assuming this is session based. Ideally db query)
    // Re-reading all sessions for badge calculation logic since we need full history
    final allSessions = await DatabaseService.instance.readAllSessions();
    int totalAllMinutes =
        allSessions.fold(0, (sum, s) => sum + s.duration) ~/ 60;

    // Load Streak
    int streak = 0;
    // ... Existing streak logic will follow below using allSessions

    if (allSessions.isNotEmpty) {
      final now = DateTime.now();
      final todayDate = DateTime(now.year, now.month, now.day);
      final sessionsByDate = <String, bool>{};
      for (var s in allSessions) {
        final key =
            "${s.timestamp.year}-${s.timestamp.month}-${s.timestamp.day}";
        sessionsByDate[key] = true;
      }
      DateTime checkDate = todayDate;
      final todayKey = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
      if (!sessionsByDate.containsKey(todayKey)) {
        checkDate = checkDate.subtract(const Duration(days: 1));
      }
      while (true) {
        final key = "${checkDate.year}-${checkDate.month}-${checkDate.day}";
        if (sessionsByDate.containsKey(key)) {
          streak++;
          checkDate = checkDate.subtract(const Duration(days: 1));
        } else {
          break;
        }
      }
    }

    // Calculate Badges
    final badges = BadgeData.calculateBadges(
      sessions: allSessions,
      streak: streak,
      totalMinutes: totalAllMinutes,
    );

    // Load Top 3 Uncompleted Tasks
    final todos = await DatabaseService.instance.readAllTodos();
    final topTasks = todos.where((t) => !t.isCompleted).take(3).toList();

    if (mounted) {
      setState(() {
        _lastSession = session;
        _dailyMinutes = minutes;
        _streak = streak;
        _badges = badges;
        _topTasks = topTasks;
        _isLoading = false;
      });
    }
  }

  Future<void> _checkAndShowTutorial() async {
    // Wait for the UI to build
    await Future.delayed(Duration.zero);

    // Uncomment next line to force test tutorial during development
    // await OnboardingService.resetOnboarding();

    if (await OnboardingService.shouldShowOnboarding()) {
      // Delay slightly for smooth entrance
      Future.delayed(const Duration(seconds: 1), () {
        if (mounted) _showTutorial();
      });
    }
  }

  void _showTutorial() {
    _tutorialCoachMark = TutorialCoachMark(
      targets: _createTargets(),
      colorShadow: Colors.black, // Darker shadow
      textSkip: "SKIP",
      paddingFocus: 10,
      opacityShadow: 0.85, // Darker opacity
      imageFilter: ImageFilter.blur(
        sigmaX: 3,
        sigmaY: 3,
      ), // Subtle background blur
      hideSkip: true, // We have our own skip button in the card
      onFinish: () {
        OnboardingService.markOnboardingComplete();
      },
      onClickTarget: (target) {
        _tutorialCoachMark.next();
      },
      onSkip: () {
        OnboardingService.markOnboardingComplete();
        return true;
      },
    );

    _tutorialCoachMark.show(context: context);
  }

  List<TargetFocus> _createTargets() {
    return [
      TargetFocus(
        identify: "Header",
        keyTarget: _headerKey,
        alignSkip: Alignment.topRight,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return PremiumTutorialCard(
                title: "Welcome to FocusPilot! ✈️",
                description:
                    "Your personal cockpit for productivity.\nLet's take a quick flight check.",
                onNext: () => _tutorialCoachMark.next(),
                onSkip: () => _tutorialCoachMark.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "Calendar",
        keyTarget: _calendarKey,
        alignSkip: Alignment.bottomLeft,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return PremiumTutorialCard(
                title: "Time Travel 📅",
                description:
                    "Tap here to view your full history and past sessions in the Calendar.",
                onNext: () => _tutorialCoachMark.next(),
                onSkip: () => _tutorialCoachMark.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "DailyCard",
        keyTarget: _dailyCardKey,
        shape: ShapeLightFocus.RRect,
        radius: 24,
        contents: [
          TargetContent(
            align: ContentAlign.bottom,
            builder: (context, controller) {
              return PremiumTutorialCard(
                title: "Track Your Daily Fuel",
                description:
                    "See your total focus time and progress towards your daily goal right here.",
                onNext: () => _tutorialCoachMark.next(),
                onSkip: () => _tutorialCoachMark.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "StartSession",
        keyTarget: _startSessionKey,
        shape: ShapeLightFocus.RRect,
        radius: 24,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return PremiumTutorialCard(
                title: "Ready for Takeoff?",
                description:
                    "Tap a category like 'Work' to start your focus timer and block distractions.",
                onNext: () => _tutorialCoachMark.next(),
                onSkip: () => _tutorialCoachMark.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "TasksTab",
        keyTarget: _tasksTabKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return PremiumTutorialCard(
                title: "Daily Tasks ✅",
                description:
                    "Switch to this tab to manage your daily to-do list and goals.",
                onNext: () => _tutorialCoachMark.next(),
                onSkip: () => _tutorialCoachMark.skip(),
              );
            },
          ),
        ],
      ),
      TargetFocus(
        identify: "StatsTab",
        keyTarget: _statsTabKey,
        shape: ShapeLightFocus.Circle,
        contents: [
          TargetContent(
            align: ContentAlign.top,
            builder: (context, controller) {
              return PremiumTutorialCard(
                title: "Flight Data Recorder",
                description:
                    "Check your history, streaks, and detailed productivity stats.",
                onNext: () => _tutorialCoachMark.finish(),
                isLast: true,
              );
            },
          ),
        ],
      ),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        bottom: false, // Allow content to flow behind nav bar
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Fixed Header
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 24.0,
                vertical: 24.0,
              ),
              child: Column(
                children: [
                  HomeHeader(key: _headerKey, dateKey: _calendarKey),
                  const SizedBox(height: 2), // The gap user requested
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  24.0,
                  0,
                  24.0,
                  120.0,
                ), // No top padding, only 24 horizontal
                children: [
                  // Daily Insight Card
                  DailyProgressCard(
                    keyTarget: _dailyCardKey,
                    totalMinutes: _dailyMinutes,
                    streak: _streak,
                    badges: _badges,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),

                  // Section Title
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Start a Session',
                        style: Theme.of(context).textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const CreatePlanScreen(),
                            ),
                          );
                        },
                        icon: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: AppTheme.primaryColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.add,
                            color: AppTheme.primaryColor,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),

                  // Premium Grid
                  GridView.count(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    padding: EdgeInsets.zero,
                    crossAxisCount: 2,
                    mainAxisSpacing: 16,
                    crossAxisSpacing: 16,
                    childAspectRatio: 1.0,
                    children: [
                      _buildCategoryCard(
                        context,
                        key: _startSessionKey,
                        title: 'Work',
                        subtitle: 'Focus & Grind',
                        icon: CupertinoIcons.briefcase,
                        gradientColors: const [
                          Color(0xFF4481EB),
                          Color(0xFF04BEFE),
                        ], // Blue
                        onTap: () => _navigateToTimer(context, 'work'),
                      ),
                      _buildCategoryCard(
                        context,
                        title: 'Personal',
                        subtitle: 'Me Time',
                        icon: CupertinoIcons.person,
                        gradientColors: const [
                          Color(0xFF9F44D3),
                          Color(0xFFA66BE2),
                        ], // Purple
                        onTap: () => _navigateToTimer(context, 'personal'),
                      ),
                      _buildCategoryCard(
                        context,
                        title: 'Reading',
                        subtitle: 'Learn & Grow',
                        icon: CupertinoIcons.book,
                        gradientColors: const [
                          Color(0xFFFF9A44),
                          Color(0xFFFC6076),
                        ], // Orange
                        onTap: () => _navigateToTimer(context, 'reading'),
                      ),
                      _buildCategoryCard(
                        context,
                        title: 'Sleep',
                        subtitle: 'Rest & Recover',
                        icon: CupertinoIcons.moon,
                        gradientColors: const [
                          Color(0xFF1A1B2E),
                          Color(0xFF4A148C),
                        ], // Dark Blue/Purple
                        onTap: () => _navigateToTimer(context, 'sleep'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),

                  const SizedBox(height: 24),

                  // Last Session Card
                  LastSessionCard(
                    lastSession: _lastSession,
                    isLoading: _isLoading,
                  ),
                  const SizedBox(height: 24),

                  QuickTasksCard(
                    topTasks: _topTasks,
                    isLoading: _isLoading,
                    onRefresh: _loadData,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      extendBody: true,
      bottomNavigationBar: Container(
        margin: const EdgeInsets.fromLTRB(19, 0, 19, 24),
        height: 75,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(37.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isDark ? 0.3 : 0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(37.5),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
            child: Container(
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF2D2D44).withOpacity(0.85)
                    : Colors.white.withOpacity(0.85),
                borderRadius: BorderRadius.circular(37.5),
                border: Border.all(
                  color: isDark
                      ? Colors.white12
                      : Colors.white.withOpacity(0.2),
                  width: 0.5,
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildNavIcon(
                    context,
                    icon: CupertinoIcons.home,
                    isActive: true, // Always active on Home
                    onTap: () {}, // No-op on home
                  ),
                  _buildNavIcon(
                    context,
                    icon: CupertinoIcons.list_bullet,
                    key: _tasksTabKey,
                    onTap: () async {
                      await Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const TodoListScreen(),
                        ),
                      );
                      _loadData(); // Refresh in case tasks were completed (though less critical for these cards)
                    },
                  ),
                  _buildNavIcon(
                    context,
                    icon: CupertinoIcons.graph_square,
                    key: _statsTabKey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const StatsScreen(),
                        ),
                      );
                    },
                  ),
                  _buildNavIcon(
                    context,
                    icon: CupertinoIcons.settings,
                    key: _settingsTabKey,
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => const SettingsScreen(),
                        ),
                      );
                    },
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildNavIcon(
    BuildContext context, {
    required IconData icon,
    required VoidCallback onTap,
    Key? key,
    bool isActive = false,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      key: key,
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Container(
        padding: const EdgeInsets.all(12),
        child: Icon(
          icon,
          size: 33,
          color: isActive
              ? AppTheme.primaryColor
              : (isDark ? Colors.white38 : Colors.black45),
        ),
      ),
    );
  }

  Widget _buildCategoryCard(
    BuildContext context, {
    Key? key,
    required String title,
    required String subtitle,
    required IconData icon,
    required List<Color> gradientColors,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.hardEdge,
        child: Stack(
          children: [
            // Decorative background icon
            Positioned(
              right: -10,
              bottom: -10,
              child: Transform.rotate(
                angle: -0.2,
                child: Icon(
                  icon,
                  size: 80,
                  color: Colors.white.withOpacity(0.15),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(icon, size: 24, color: Colors.white),
                  ),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _navigateToTimer(BuildContext context, String category) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => CreatePlanScreen(initialCategory: category),
      ),
    );
    // Refresh data when returning from session
    _loadData();
  }
}
