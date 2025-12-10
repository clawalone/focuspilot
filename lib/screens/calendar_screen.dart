import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:intl/intl.dart';
import '../services/database_service.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';
import 'history_screen.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen>
    with SingleTickerProviderStateMixin {
  CalendarFormat _calendarFormat = CalendarFormat.month;
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;
  Map<DateTime, int> _dailyFocusMinutes = {};
  bool _isLoading = true;

  // Stats
  int _thisMonthMinutes = 0;
  int _lastMonthMinutes = 0;
  int _pastYearMinutes = 0;

  // New Stats
  String _bestDayDate = '-';
  int _bestDayMinutes = 0;

  List<Session> _selectedDaySessions = [];

  // Animation
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

    _loadData();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _loadData() async {
    try {
      final sessions = await DatabaseService.instance.readAllSessions();
      _processSessions(sessions);

      // Initialize selected day to today
      final now = DateTime.now();
      _onDaySelected(now, now);

      // Allow UI to build before starting animation
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _controller.forward();
      });
    } catch (e) {
      debugPrint('Error loading data: $e');
      setState(() => _isLoading = false);
    }
  }

  Future<void> _onDaySelected(DateTime selectedDay, DateTime focusedDay) async {
    final sessions = await DatabaseService.instance.readSessionsForDate(
      selectedDay,
    );
    if (!mounted) return;
    setState(() {
      _selectedDay = selectedDay;
      _focusedDay = focusedDay;
      _selectedDaySessions = sessions;
    });
  }

  void _processSessions(List<Session> sessions) {
    Map<DateTime, int> dailyMinutes = {};
    int thisMonth = 0;
    int lastMonth = 0;
    int pastYear = 0;

    final now = DateTime.now();
    final currentMonthStart = DateTime(now.year, now.month, 1);
    final lastMonthStart = DateTime(now.year, now.month - 1, 1);
    final lastMonthEnd = DateTime(now.year, now.month, 0);
    final pastYearStart = DateTime(now.year - 1, now.month, now.day);

    // For Best Day Calc
    int maxMinutes = 0;
    DateTime? bestDate;

    for (var session in sessions) {
      final date = DateTime(
        session.timestamp.year,
        session.timestamp.month,
        session.timestamp.day,
      );
      final minutes = session.duration ~/ 60;

      dailyMinutes[date] = (dailyMinutes[date] ?? 0) + minutes;

      if (session.timestamp.isAfter(currentMonthStart) ||
          session.timestamp.isAtSameMomentAs(currentMonthStart)) {
        thisMonth += minutes;
      }

      if (session.timestamp.isAfter(
            lastMonthStart.subtract(const Duration(seconds: 1)),
          ) &&
          session.timestamp.isBefore(
            lastMonthEnd.add(const Duration(days: 1)),
          )) {
        lastMonth += minutes;
      }

      if (session.timestamp.isAfter(pastYearStart)) {
        pastYear += minutes;
      }
    }

    // Find Best Day
    dailyMinutes.forEach((date, minutes) {
      if (minutes > maxMinutes) {
        maxMinutes = minutes;
        bestDate = date;
      }
    });

    setState(() {
      _dailyFocusMinutes = dailyMinutes;
      _thisMonthMinutes = thisMonth;
      _lastMonthMinutes = lastMonth;
      _pastYearMinutes = pastYear;
      _bestDayMinutes = maxMinutes;
      _bestDayDate = bestDate != null
          ? DateFormat('MMM d').format(bestDate!)
          : '-';
      _isLoading = false;
    });
  }

  String _formatDuration(int minutes) {
    if (minutes < 60) {
      return '${minutes}m';
    }
    final hours = minutes ~/ 60;
    final mins = minutes % 60;
    return '${hours}h ${mins}m';
  }

  List<int> _getEventsForDay(DateTime day) {
    final date = DateTime(day.year, day.month, day.day);
    final minutes = _dailyFocusMinutes[date];
    if (minutes != null && minutes > 0) {
      return [minutes];
    }
    return [];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          // Mesh-like subtle radial gradients (Matches StatsScreen)
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
                          padding: const EdgeInsets.all(24),
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
                                    'Focus History',
                                    style: theme.textTheme.headlineSmall
                                        ?.copyWith(fontWeight: FontWeight.bold),
                                  ),
                                  TextButton(
                                    onPressed: () {
                                      Navigator.push(
                                        context,
                                        MaterialPageRoute(
                                          builder: (context) =>
                                              const HistoryScreen(),
                                        ),
                                      );
                                    },
                                    child: const Text('View All'),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 32),

                              // Calendar Card
                              Container(
                                decoration: BoxDecoration(
                                  color: theme.colorScheme.surface,
                                  borderRadius: BorderRadius.circular(24),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      blurRadius: 15,
                                      offset: const Offset(0, 8),
                                    ),
                                  ],
                                ),
                                padding: const EdgeInsets.all(16),
                                child: TableCalendar(
                                  firstDay: DateTime.utc(2020, 1, 1),
                                  lastDay: DateTime.utc(2030, 12, 31),
                                  focusedDay: _focusedDay,
                                  calendarFormat: _calendarFormat,
                                  selectedDayPredicate: (day) =>
                                      isSameDay(_selectedDay, day),
                                  onDaySelected: _onDaySelected,
                                  onFormatChanged: (format) {
                                    setState(() {
                                      _calendarFormat = format;
                                    });
                                  },
                                  eventLoader: _getEventsForDay,
                                  calendarStyle: CalendarStyle(
                                    outsideDaysVisible: false,
                                    todayDecoration: BoxDecoration(
                                      color: AppTheme.primaryColor.withOpacity(
                                        0.3,
                                      ),
                                      shape: BoxShape.circle,
                                    ),
                                    selectedDecoration: const BoxDecoration(
                                      color: Colors
                                          .transparent, // Handled in builder
                                    ),
                                    markerDecoration: const BoxDecoration(
                                      color: Colors
                                          .transparent, // Handled in builder
                                    ),
                                  ),
                                  headerStyle: HeaderStyle(
                                    formatButtonVisible: false,
                                    titleCentered: true,
                                    titleTextStyle: theme.textTheme.titleMedium!
                                        .copyWith(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 18,
                                        ),
                                    leftChevronIcon: Icon(
                                      Icons.chevron_left,
                                      color: theme.iconTheme.color,
                                    ),
                                    rightChevronIcon: Icon(
                                      Icons.chevron_right,
                                      color: theme.iconTheme.color,
                                    ),
                                  ),
                                  // Custom Builders for Heatmap/Markers
                                  calendarBuilders: CalendarBuilders(
                                    selectedBuilder: (context, date, events) {
                                      return Container(
                                        margin: const EdgeInsets.all(4),
                                        alignment: Alignment.center,
                                        decoration: BoxDecoration(
                                          color: AppTheme.primaryColor,
                                          shape: BoxShape.circle,
                                          boxShadow: [
                                            BoxShadow(
                                              color: AppTheme.primaryColor
                                                  .withOpacity(0.4),
                                              blurRadius: 8,
                                              spreadRadius: 2,
                                            ),
                                          ],
                                        ),
                                        child: Text(
                                          '${date.day}',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      );
                                    },
                                    markerBuilder: (context, date, events) {
                                      if (events.isEmpty) return null;
                                      final minutes = events.first as int;

                                      // Heatmap Logic
                                      Color markerColor;
                                      double size;
                                      IconData? icon;

                                      if (minutes > 120) {
                                        markerColor = Colors.orange;
                                        size = 8;
                                        icon = Icons.local_fire_department;
                                      } else if (minutes > 60) {
                                        markerColor = Colors.deepPurple;
                                        size = 8;
                                      } else if (minutes > 30) {
                                        markerColor = Colors.blue;
                                        size = 6;
                                      } else {
                                        markerColor = Colors.green;
                                        size = 5;
                                      }

                                      if (icon != null) {
                                        // For super high activity, show a tiny fire icon instead of dot
                                        return Positioned(
                                          bottom: 1,
                                          child: Icon(
                                            icon,
                                            size: 12,
                                            color: markerColor,
                                          ),
                                        );
                                      }

                                      return Positioned(
                                        bottom: 5,
                                        child: Container(
                                          width: size,
                                          height: size,
                                          decoration: BoxDecoration(
                                            color: markerColor,
                                            shape: BoxShape.circle,
                                          ),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                              ),
                              const SizedBox(height: 32),

                              // Selected Day Header
                              Text(
                                _selectedDay != null
                                    ? DateFormat(
                                        'MMMM d, y',
                                      ).format(_selectedDay!)
                                    : 'Select a Date',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Session List (Glassmorphism)
                              if (_selectedDaySessions.isEmpty)
                                Container(
                                  padding: const EdgeInsets.all(24),
                                  width: double.infinity,
                                  decoration: BoxDecoration(
                                    color: theme.colorScheme.surface
                                        .withOpacity(0.5),
                                    borderRadius: BorderRadius.circular(20),
                                    border: Border.all(
                                      color: Colors.grey.withOpacity(0.1),
                                    ),
                                  ),
                                  child: Column(
                                    children: [
                                      Icon(
                                        Icons.calendar_today_outlined,
                                        size: 48,
                                        color: Colors.grey.withOpacity(0.3),
                                      ),
                                      const SizedBox(height: 12),
                                      Text(
                                        'No sessions for this day',
                                        style: theme.textTheme.bodyLarge
                                            ?.copyWith(color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                )
                              else
                                ..._selectedDaySessions
                                    .map(
                                      (session) => Container(
                                        margin: const EdgeInsets.only(
                                          bottom: 12,
                                        ),
                                        padding: const EdgeInsets.all(16),
                                        decoration: BoxDecoration(
                                          color: theme.colorScheme.surface,
                                          borderRadius: BorderRadius.circular(
                                            20,
                                          ),
                                          boxShadow: [
                                            BoxShadow(
                                              color: Colors.black.withOpacity(
                                                0.05,
                                              ),
                                              blurRadius: 10,
                                              offset: const Offset(0, 4),
                                            ),
                                          ],
                                        ),
                                        child: Row(
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.all(10),
                                              decoration: BoxDecoration(
                                                gradient: LinearGradient(
                                                  colors: [
                                                    AppTheme.primaryColor
                                                        .withOpacity(0.2),
                                                    AppTheme.primaryColor
                                                        .withOpacity(0.05),
                                                  ],
                                                  begin: Alignment.topLeft,
                                                  end: Alignment.bottomRight,
                                                ),
                                                shape: BoxShape.circle,
                                              ),
                                              child: Icon(
                                                Icons.check_circle_outline,
                                                color: AppTheme.primaryColor,
                                                size: 20,
                                              ),
                                            ),
                                            const SizedBox(width: 16),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment:
                                                    CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    session.category,
                                                    style: theme
                                                        .textTheme
                                                        .bodyLarge
                                                        ?.copyWith(
                                                          fontWeight:
                                                              FontWeight.bold,
                                                        ),
                                                  ),
                                                  Text(
                                                    DateFormat(
                                                      'h:mm a',
                                                    ).format(session.timestamp),
                                                    style: theme
                                                        .textTheme
                                                        .bodySmall
                                                        ?.copyWith(
                                                          color: Colors.grey,
                                                        ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                    horizontal: 12,
                                                    vertical: 6,
                                                  ),
                                              decoration: BoxDecoration(
                                                color:
                                                    theme.brightness ==
                                                        Brightness.dark
                                                    ? Colors.white10
                                                    : Colors.grey.shade100,
                                                borderRadius:
                                                    BorderRadius.circular(12),
                                              ),
                                              child: Text(
                                                '${session.duration ~/ 60}m',
                                                style: theme
                                                    .textTheme
                                                    .titleMedium
                                                    ?.copyWith(
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      fontSize: 14,
                                                    ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    )
                                    .toList(),

                              const SizedBox(height: 32),

                              // Stats Section
                              Text(
                                'Overview',
                                style: theme.textTheme.titleLarge?.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Stats Grid
                              GridView.count(
                                shrinkWrap: true,
                                physics: const NeverScrollableScrollPhysics(),
                                crossAxisCount: 2,
                                childAspectRatio: 1.1,
                                crossAxisSpacing: 16,
                                mainAxisSpacing: 16,
                                children: [
                                  _buildPremiumStatCard(
                                    context,
                                    'This Month',
                                    _formatDuration(_thisMonthMinutes),
                                    Icons.calendar_month,
                                    Colors.blue,
                                  ),
                                  _buildPremiumStatCard(
                                    context,
                                    'Last Month',
                                    _formatDuration(_lastMonthMinutes),
                                    Icons.history_toggle_off,
                                    Colors.purple,
                                  ),
                                  _buildPremiumStatCard(
                                    context,
                                    'Best Day',
                                    _bestDayDate,
                                    Icons.workspace_premium, // Trophy
                                    Colors.orange,
                                    subtitle: _formatDuration(_bestDayMinutes),
                                  ),
                                  _buildPremiumStatCard(
                                    context,
                                    'Total Year',
                                    _formatDuration(_pastYearMinutes),
                                    Icons.timeline,
                                    Colors.teal,
                                  ),
                                ],
                              ),
                              const SizedBox(height: 40),
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

  Widget _buildPremiumStatCard(
    BuildContext context,
    String title,
    String value,
    IconData icon,
    Color color, {
    String? subtitle,
  }) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 15,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
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
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                value,
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  fontSize: 20,
                ),
              ),
              if (subtitle != null)
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              const SizedBox(height: 2),
              Text(
                title,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.grey,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
