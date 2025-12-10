import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import '../services/database_service.dart';
import '../services/settings_service.dart';

class DailyProgressCard extends StatefulWidget {
  const DailyProgressCard({super.key});

  @override
  State<DailyProgressCard> createState() => _DailyProgressCardState();
}

class _DailyProgressCardState extends State<DailyProgressCard> {
  int _totalMinutes = 0;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDailyStats();
  }

  Future<void> _loadDailyStats() async {
    final today = DateTime.now();
    final sessions = await DatabaseService.instance.readSessionsForDate(today);
    int totalSeconds = 0;
    for (var session in sessions) {
      totalSeconds += session.duration;
    }

    if (mounted) {
      setState(() {
        _totalMinutes = totalSeconds ~/ 60;
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen to settings changes
    final settings = Provider.of<SettingsService>(context);
    final dailyGoal = settings.getDailyGoal();

    final progress = (_totalMinutes / dailyGoal).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: isDark
            ? const LinearGradient(
                colors: [Color(0xFF2D2D44), Color(0xFF1A1B2E)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              )
            : const LinearGradient(
                colors: [Color(0xFF6C63FF), Color(0xFF4834D4)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: (isDark ? Colors.black : AppTheme.primaryColor).withOpacity(
              0.3,
            ),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Daily Focus',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: Colors.white70,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  '${_totalMinutes}m',
                  style: theme.textTheme.displayMedium?.copyWith(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  'of ${dailyGoal}m goal',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    progress >= 1.0 ? 'Goal Reached! 🎉' : 'Keep going! 🔥',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
          CircularPercentIndicator(
            radius: 50.0,
            lineWidth: 10.0,
            percent: progress,
            center: Text(
              "${(progress * 100).toInt()}%",
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            progressColor: Colors.white,
            backgroundColor: Colors.white.withOpacity(0.2),
            circularStrokeCap: CircularStrokeCap.round,
            animation: true,
          ),
        ],
      ),
    );
  }
}
