import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';

import '../services/settings_service.dart';
import '../models/badge_data.dart';

class DailyProgressCard extends StatelessWidget {
  final int totalMinutes;
  final int streak;
  final List<BadgeData> badges;
  final bool isLoading;
  final GlobalKey? keyTarget; // Renaming to avoid conflict with widget.key

  const DailyProgressCard({
    super.key,
    this.totalMinutes = 0,
    this.streak = 0,
    this.badges = const [],
    this.isLoading = false,
    this.keyTarget,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    // Listen to settings changes
    final settings = Provider.of<SettingsService>(context);
    final dailyGoal = settings.getDailyGoal();

    final progress = (totalMinutes / dailyGoal).clamp(0.0, 1.0);

    if (isDark) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            key: keyTarget,
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppTheme.statsCardBackground.withOpacity(0.7),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: Colors.white.withOpacity(0.1),
                width: 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.2),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: _buildContent(context, isDark, progress),
          ),
        ),
      );
    }

    return Container(
      key: keyTarget,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 15,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: _buildContent(context, isDark, progress),
    );
  }

  Widget _buildContent(BuildContext context, bool isDark, double progress) {
    final theme = Theme.of(context);
    final contentColor = isDark ? Colors.white : Colors.black87;
    final secondaryContentColor = isDark ? Colors.white70 : Colors.black54;
    final tertiaryContentColor = isDark ? Colors.white60 : Colors.black45;

    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Daily Focus',
                style: theme.textTheme.titleMedium?.copyWith(
                  color: secondaryContentColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${totalMinutes}m',
                style: theme.textTheme.displayMedium?.copyWith(
                  color: contentColor,
                  fontSize: 32,
                  fontWeight: FontWeight.bold,
                ),
              ),
              Text(
                'of ${totalMinutes > 0 ? (totalMinutes / progress).toInt() : 0}m goal', // Recover goal from progress
                style: theme.textTheme.bodySmall?.copyWith(
                  color: tertiaryContentColor,
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  if (streak > 0) ...[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.2),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Row(
                        children: [
                          const Text('🔥', style: TextStyle(fontSize: 12)),
                          const SizedBox(width: 4),
                          Text(
                            '$streak',
                            style: const TextStyle(
                              color: Colors.orangeAccent,
                              fontWeight: FontWeight.bold,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDark
                          ? Colors.white.withOpacity(0.2)
                          : AppTheme.primaryColor.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      progress >= 1.0 ? 'Goal Reached! 🎉' : 'Keep going!',
                      style: TextStyle(
                        color: isDark ? Colors.white : AppTheme.primaryColor,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  if (badges.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ...badges
                        .where((b) => b.isUnlocked)
                        .take(3)
                        .map(
                          (b) => Padding(
                            padding: const EdgeInsets.only(right: 4.0),
                            child: Tooltip(
                              message: b.title,
                              child: Icon(
                                b.icon,
                                size: 16,
                                color: b.color.withOpacity(0.9),
                              ),
                            ),
                          ),
                        ),
                  ],
                ],
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
            style: TextStyle(
              color: contentColor,
              fontWeight: FontWeight.bold,
              fontSize: 18,
            ),
          ),
          progressColor: AppTheme.primaryColor,
          backgroundColor: isDark
              ? Colors.white.withOpacity(0.1)
              : Colors.black.withOpacity(0.05),
          circularStrokeCap: CircularStrokeCap.round,
          animation: true,
        ),
      ],
    );
  }
}
