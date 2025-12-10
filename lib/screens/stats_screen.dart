import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/database_service.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import 'sessions_screen.dart';

class StatsScreen extends StatefulWidget {
  const StatsScreen({super.key});

  @override
  State<StatsScreen> createState() => _StatsScreenState();
}

class _StatsScreenState extends State<StatsScreen>
    with SingleTickerProviderStateMixin {
  List<Session> _sessions = [];
  bool _isLoading = true;

  // Stats
  int _totalMinutes = 0;
  int _sessionsCount = 0;
  int _blockedAppsCount = 0;
  double _progress = 0.0;
  int _score = 0;
  int _streak = 0;
  Map<String, int> _categoryMinutes = {};

  late AnimationController _controller;
  late Animation<double> _fadeAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _loadSessions();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadSessions() async {
    try {
      setState(() => _isLoading = true);
      final sessions = await DatabaseService.instance.readAllSessions();

      int totalSeconds = 0;
      int blockedApps = 0;
      Map<String, int> categorySeconds = {};

      for (var session in sessions) {
        totalSeconds += session.duration;
        blockedApps += session.appsLimitedCount;
        categorySeconds[session.category] =
            (categorySeconds[session.category] ?? 0) + session.duration;
      }

      final totalMinutes = totalSeconds ~/ 60;
      final score = totalMinutes;
      final progress = (totalMinutes / 240).clamp(0.0, 1.0);
      final streak = _calculateStreak(sessions);

      // Convert category seconds to minutes
      final Map<String, int> categoryMinutes = {};
      categorySeconds.forEach((key, value) {
        categoryMinutes[key] = value ~/ 60;
      });

      setState(() {
        _sessions = sessions;
        _totalMinutes = totalMinutes;
        _sessionsCount = sessions.length;
        _blockedAppsCount = blockedApps;
        _score = score;
        _progress = progress;
        _streak = streak;
        _categoryMinutes = categoryMinutes;
        _isLoading = false;
      });
      _controller.forward();
    } catch (e) {
      debugPrint('Error loading sessions: $e');
      setState(() {
        _sessions = [];
        _isLoading = false;
      });
    }
  }

  int _calculateStreak(List<Session> sessions) {
    if (sessions.isEmpty) return 0;
    final dates = sessions
        .map(
          (s) => DateTime(s.timestamp.year, s.timestamp.month, s.timestamp.day),
        )
        .toSet()
        .toList();
    dates.sort((a, b) => b.compareTo(a));
    if (dates.isEmpty) return 0;

    final today = DateTime.now();
    final todayDate = DateTime(today.year, today.month, today.day);
    final yesterdayDate = todayDate.subtract(const Duration(days: 1));

    if (dates.first.isBefore(yesterdayDate)) return 0;

    int streak = 1;
    DateTime currentDate = dates.first;
    for (int i = 1; i < dates.length; i++) {
      if (currentDate.difference(dates[i]).inDays == 1) {
        streak++;
        currentDate = dates[i];
      } else {
        break;
      }
    }
    return streak;
  }

  Color _getColorForCategory(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return AppTheme.statsAccentGreen;
      case 'personal':
        return AppTheme.statsAccentPurple;
      case 'reading':
        return Colors.orange;
      case 'sleep':
        return Colors.blue;
      default:
        return Colors.grey;
    }
  }

  List<PieChartSectionData> _buildChartSections(ThemeData theme) {
    List<PieChartSectionData> sections = [];

    // Daily goal in minutes
    const int dailyGoal = 240;
    int currentTotal = 0;

    // Add sections for each category
    _categoryMinutes.forEach((category, minutes) {
      if (minutes > 0) {
        sections.add(
          PieChartSectionData(
            color: _getColorForCategory(category),
            value: minutes.toDouble(),
            title: '',
            radius: 15,
            showTitle: false,
          ),
        );
        currentTotal += minutes;
      }
    });

    // Add remaining part of the gauge (background)
    final remaining = dailyGoal - currentTotal;
    if (remaining > 0) {
      sections.add(
        PieChartSectionData(
          color: theme.colorScheme.surface,
          value: remaining.toDouble(),
          title: '',
          radius: 15,
          showTitle: false,
        ),
      );
    }

    // Add invisible bottom half to create semi-circle effect
    // The bottom half should equal the total of the top half (which is the dailyGoal)
    sections.add(
      PieChartSectionData(
        color: Colors.transparent,
        value: dailyGoal.toDouble(),
        title: '',
        radius: 15,
        showTitle: false,
      ),
    );

    return sections;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Mesh-like subtle radial gradients for a premium feel
          color: isDark ? const Color(0xFF0F0F1E) : const Color(0xFFF8F9FE),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: isDark
                ? [
                    const Color(0xFF1A1A2E),
                    const Color(0xFF0F0F1E),
                    const Color(0xFF16162C),
                  ]
                : [
                    const Color(0xFFFFFFFF),
                    const Color(0xFFF0F4FF),
                    const Color(0xFFE8EAF6),
                  ],
          ),
        ),
        child: SafeArea(
          child: _isLoading
              ? const Center(child: CircularProgressIndicator())
              : AnimatedBuilder(
                  animation: _controller,
                  builder: (context, child) {
                    return FadeTransition(
                      opacity: _fadeAnimation,
                      child: SlideTransition(
                        position: _slideAnimation,
                        child: SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              // Custom App Bar
                              Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      Icons.arrow_back_ios,
                                      color: theme.iconTheme.color,
                                    ),
                                    onPressed: () => Navigator.pop(context),
                                  ),
                                  Text(
                                    'Your Activity',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  const SizedBox(width: 40),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Score & Streak Header
                              Center(
                                child: Column(
                                  children: [
                                    _buildAnimatedStreak(theme),
                                    const SizedBox(height: 24),

                                    // Score Gauge with Animation
                                    SizedBox(
                                      height: 130,
                                      child: Stack(
                                        alignment: Alignment.bottomCenter,
                                        children: [
                                          OverflowBox(
                                            minHeight: 260,
                                            maxHeight: 260,
                                            alignment: Alignment.topCenter,
                                            child: TweenAnimationBuilder<double>(
                                              tween: Tween(begin: 0, end: 1),
                                              duration: const Duration(
                                                milliseconds: 1500,
                                              ),
                                              curve: Curves.easeOutQuart,
                                              builder: (context, value, child) {
                                                return Opacity(
                                                  opacity: value,
                                                  child: PieChart(
                                                    PieChartData(
                                                      startDegreeOffset: 180,
                                                      sectionsSpace: 0,
                                                      centerSpaceRadius: 100,
                                                      sections:
                                                          _buildChartSections(
                                                            theme,
                                                          ),
                                                      borderData: FlBorderData(
                                                        show: false,
                                                      ),
                                                    ),
                                                  ),
                                                );
                                              },
                                            ),
                                          ),
                                          Column(
                                            mainAxisSize: MainAxisSize.min,
                                            mainAxisAlignment:
                                                MainAxisAlignment.end,
                                            children: [
                                              _Countup(
                                                value: _score,
                                                style: theme
                                                    .textTheme
                                                    .displayLarge
                                                    ?.copyWith(
                                                      fontSize: 48,
                                                      height: 1.0,
                                                    ),
                                              ),
                                              const SizedBox(height: 4),
                                              Text(
                                                "You're doing excellent!",
                                                style:
                                                    theme.textTheme.bodyMedium,
                                              ),
                                              const SizedBox(height: 10),
                                            ],
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 24),
                                    _buildCategoryBreakdown(theme),
                                    const SizedBox(height: 32),

                                    // Weekly Activity Chart
                                    Text(
                                      'Weekly Activity',
                                      style: theme.textTheme.titleLarge,
                                    ),
                                    const SizedBox(height: 16),
                                    _buildWeeklyChart(theme),

                                    const SizedBox(height: 32),

                                    // Overview Grid
                                    Text(
                                      'Overview',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    GridView.count(
                                      shrinkWrap: true,
                                      physics:
                                          const NeverScrollableScrollPhysics(),
                                      crossAxisCount: 2,
                                      crossAxisSpacing: 16,
                                      mainAxisSpacing: 16,
                                      childAspectRatio: 1.3,
                                      children: [
                                        _buildPremiumStatCard(
                                          'Total Focus',
                                          _totalMinutes,
                                          Icons.timer,
                                          Colors.blue,
                                          theme,
                                          isDark,
                                          isTime: true,
                                        ),
                                        _buildPremiumStatCard(
                                          'Sessions',
                                          _sessionsCount,
                                          Icons.layers,
                                          Colors.purple,
                                          theme,
                                          isDark,
                                          onTap: () {
                                            Navigator.push(
                                              context,
                                              MaterialPageRoute(
                                                builder: (context) =>
                                                    SessionsScreen(
                                                      sessions: _sessions,
                                                    ),
                                              ),
                                            );
                                          },
                                        ),
                                        _buildPremiumStatCard(
                                          'Blocked Apps',
                                          _blockedAppsCount,
                                          Icons.block,
                                          Colors.red,
                                          theme,
                                          isDark,
                                        ),
                                        _buildPremiumStatCard(
                                          'Daily Goal',
                                          (_progress * 100).toInt(),
                                          Icons.track_changes,
                                          Colors.green,
                                          theme,
                                          isDark,
                                          suffix: '%',
                                        ),
                                      ],
                                    ),

                                    const SizedBox(height: 32),

                                    // Achievements
                                    Text(
                                      'Badges',
                                      style: theme.textTheme.titleLarge
                                          ?.copyWith(
                                            fontWeight: FontWeight.bold,
                                          ),
                                    ),
                                    const SizedBox(height: 16),
                                    SingleChildScrollView(
                                      scrollDirection: Axis.horizontal,
                                      clipBehavior: Clip.none,
                                      child: Row(
                                        children: [
                                          _buildPremiumBadge(
                                            theme,
                                            'First Step',
                                            Icons.flag,
                                            _totalMinutes > 0,
                                            Colors.blue,
                                            isDark,
                                            0,
                                          ),
                                          const SizedBox(width: 16),
                                          _buildPremiumBadge(
                                            theme,
                                            'On Fire',
                                            Icons.local_fire_department,
                                            _streak >= 3,
                                            Colors.orange,
                                            isDark,
                                            100,
                                          ),
                                          const SizedBox(width: 16),
                                          _buildPremiumBadge(
                                            theme,
                                            'Zen Master',
                                            Icons.self_improvement,
                                            _totalMinutes >= 1000,
                                            Colors.purple,
                                            isDark,
                                            200,
                                          ),
                                          const SizedBox(width: 16),
                                          _buildPremiumBadge(
                                            theme,
                                            'Night Owl',
                                            Icons.nightlight_round,
                                            false,
                                            Colors.indigo,
                                            isDark,
                                            300,
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(height: 40),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }

  Widget _buildAnimatedStreak(ThemeData theme) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: const Duration(milliseconds: 1000),
      curve: Curves.elasticOut,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Colors.orange.withOpacity(0.2),
                  Colors.red.withOpacity(0.2),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: Colors.orange.withOpacity(0.5)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(
                  Icons.local_fire_department,
                  color: Colors.orange,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  '$_streak Day Streak',
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: Colors.orange[700],
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildWeeklyChart(ThemeData theme) {
    return Container(
      height: 200,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: BarChart(
        BarChartData(
          gridData: FlGridData(show: false),
          titlesData: FlTitlesData(
            leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  const days = ['M', 'T', 'W', 'T', 'F', 'S', 'S'];
                  if (value.toInt() >= 0 && value.toInt() < days.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        days[value.toInt()],
                        style: theme.textTheme.labelMedium,
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                },
              ),
            ),
          ),
          borderData: FlBorderData(show: false),
          barGroups: List.generate(7, (index) {
            final date = DateTime.now().subtract(Duration(days: 6 - index));
            int minutes = 0;
            for (var s in _sessions) {
              if (s.timestamp.year == date.year &&
                  s.timestamp.month == date.month &&
                  s.timestamp.day == date.day) {
                minutes += s.duration ~/ 60;
              }
            }

            return BarChartGroupData(
              x: index,
              barRods: [
                BarChartRodData(
                  toY: minutes.toDouble(),
                  color: AppTheme.primaryColor,
                  width: 16,
                  borderRadius: BorderRadius.circular(4),
                  backDrawRodData: BackgroundBarChartRodData(
                    show: true,
                    toY: 240,
                    color: theme.brightness == Brightness.dark
                        ? Colors.white10
                        : Colors.grey.shade200,
                  ),
                ),
              ],
            );
          }),
          maxY: 240, // Ensure bars have room
        ),
        swapAnimationDuration: const Duration(
          milliseconds: 600,
        ), // Animate chart updates
        swapAnimationCurve: Curves.easeInOut,
      ),
    );
  }

  Widget _buildPremiumStatCard(
    String title,
    int value, // Changed to int for counting
    IconData icon,
    Color color,
    ThemeData theme,
    bool isDark, {
    bool isTime = false,
    String? suffix,
    VoidCallback? onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: BorderRadius.circular(24),
          boxShadow: [
            BoxShadow(
              color: color.withOpacity(0.1),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: color, size: 20),
                ),
                if (onTap != null)
                  Icon(
                    Icons.arrow_forward_ios_rounded,
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.4),
                    size: 16,
                  ),
              ],
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                isTime
                    ? Row(
                        crossAxisAlignment: CrossAxisAlignment.baseline,
                        textBaseline: TextBaseline.alphabetic,
                        children: [
                          _Countup(
                            value: value ~/ 60,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            'h ',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          _Countup(
                            value: value % 60,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          Text(
                            'm',
                            style: theme.textTheme.bodySmall?.copyWith(
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      )
                    : Row(
                        children: [
                          _Countup(
                            value: value,
                            style: theme.textTheme.headlineSmall?.copyWith(
                              fontWeight: FontWeight.bold,
                              fontSize: 24,
                            ),
                          ),
                          if (suffix != null)
                            Text(
                              suffix,
                              style: theme.textTheme.headlineSmall?.copyWith(
                                fontWeight: FontWeight.bold,
                                fontSize: 24,
                              ),
                            ),
                        ],
                      ),
                const SizedBox(height: 4),
                Text(
                  title,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.textTheme.bodyMedium?.color?.withOpacity(0.6),
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildPremiumBadge(
    ThemeData theme,
    String title,
    IconData icon,
    bool unlocked,
    Color color,
    bool isDark,
    int delay,
  ) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 600 + delay),
      curve: Curves.easeOutBack,
      builder: (context, value, child) {
        return Transform.scale(
          scale: value,
          child: Container(
            width: 100,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: unlocked
                    ? [color.withOpacity(0.2), color.withOpacity(0.05)]
                    : [
                        Colors.grey.withOpacity(0.1),
                        Colors.grey.withOpacity(0.05),
                      ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: unlocked ? color.withOpacity(0.3) : Colors.transparent,
                width: 1.5,
              ),
            ),
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: unlocked
                        ? color.withOpacity(0.2)
                        : Colors.grey.withOpacity(0.1),
                    shape: BoxShape.circle,
                    boxShadow: unlocked
                        ? [
                            BoxShadow(
                              color: color.withOpacity(0.3),
                              blurRadius: 10,
                              spreadRadius: 2,
                            ),
                          ]
                        : [],
                  ),
                  child: Icon(
                    icon,
                    color: unlocked ? color : Colors.grey,
                    size: 28,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.labelMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: unlocked
                        ? (isDark ? Colors.white : Colors.black87)
                        : Colors.grey,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildCategoryBreakdown(ThemeData theme) {
    if (_categoryMinutes.isEmpty) return const SizedBox.shrink();

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      alignment: WrapAlignment.center,
      children: _categoryMinutes.entries.map((entry) {
        if (entry.value == 0) return const SizedBox.shrink();
        final color = _getColorForCategory(entry.key);
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: color.withOpacity(0.2)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 8,
                height: 8,
                decoration: BoxDecoration(color: color, shape: BoxShape.circle),
              ),
              const SizedBox(width: 8),
              Text(
                '${entry.key} ${entry.value}m',
                style: theme.textTheme.labelMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                  color: color, // Match text color to category for cleaner look
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }
}

class _Countup extends StatelessWidget {
  final int value;
  final TextStyle? style;

  const _Countup({required this.value, this.style});

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<int>(
      tween: IntTween(begin: 0, end: value),
      duration: const Duration(milliseconds: 1500),
      curve: Curves.easeOutExpo,
      builder: (context, val, child) {
        return Text('$val', style: style);
      },
    );
  }
}
