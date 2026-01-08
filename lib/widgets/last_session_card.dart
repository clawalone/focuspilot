import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';

class LastSessionCard extends StatelessWidget {
  final Session? lastSession;
  final bool isLoading;

  const LastSessionCard({super.key, this.lastSession, this.isLoading = false});

  @override
  Widget build(BuildContext context) {
    if (isLoading || lastSession == null) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;
    final session = lastSession!;
    final durationMins = session.duration ~/ 60;

    // Format timestamp nicely (e.g., "Today, 2:30 PM")
    final now = DateTime.now();
    final isToday =
        session.timestamp.year == now.year &&
        session.timestamp.month == now.month &&
        session.timestamp.day == now.day;
    final dateStr = isToday
        ? 'Today'
        : DateFormat('MMM d').format(session.timestamp);
    final timeStr = DateFormat('h:mm a').format(session.timestamp);

    return Column(
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.only(
            left: 4.0,
            right: 4.0,
            bottom: 8.0,
            top: 0.0,
          ),
          child: Row(
            children: [
              Text(
                'Last Flight',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
            ],
          ),
        ),

        // Card
        isDark
            ? ClipRRect(
                borderRadius: BorderRadius.circular(24),
                child: BackdropFilter(
                  filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
                  child: Container(
                    padding: const EdgeInsets.all(16),
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
                    child: _buildCardContent(
                      context,
                      session,
                      isDark,
                      dateStr,
                      timeStr,
                      durationMins,
                    ),
                  ),
                ),
              )
            : Container(
                padding: const EdgeInsets.all(16),
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
                child: _buildCardContent(
                  context,
                  session,
                  isDark,
                  dateStr,
                  timeStr,
                  durationMins,
                ),
              ),
      ],
    );
  }

  Widget _buildCardContent(
    BuildContext context,
    Session session,
    bool isDark,
    String dateStr,
    String timeStr,
    int durationMins,
  ) {
    return Row(
      children: [
        // Icon Container
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: _getCategoryColor(session.category).withOpacity(0.1),
            borderRadius: BorderRadius.circular(16),
          ),
          child: Icon(
            _getCategoryIcon(session.category),
            color: _getCategoryColor(session.category),
            size: 24,
          ),
        ),
        const SizedBox(width: 16),

        // Details
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                session.category,
                style: GoogleFonts.outfit(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
              Text(
                '$dateStr • $timeStr',
                style: TextStyle(
                  fontSize: 13,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),

        // Duration Badge
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: isDark
                ? Colors.white.withOpacity(0.05)
                : Colors.black.withOpacity(0.05),
            borderRadius: BorderRadius.circular(20),
          ),
          child: Text(
            '${durationMins}m',
            style: TextStyle(
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black87,
            ),
          ),
        ),
      ],
    );
  }

  IconData _getCategoryIcon(String category) {
    switch (category.toLowerCase()) {
      case 'work':
        return CupertinoIcons.briefcase;
      case 'personal':
        return CupertinoIcons.person;
      case 'reading':
        return CupertinoIcons.book;
      case 'sleep':
        return CupertinoIcons.moon;
      default:
        return CupertinoIcons.timer;
    }
  }

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
        return Colors.blue;
    }
  }
}
