import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'session.dart';

class BadgeData {
  final String id;
  final String title;
  final String description;
  final IconData icon;
  final Color color;
  final bool isUnlocked;

  BadgeData({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.color,
    required this.isUnlocked,
  });

  static List<BadgeData> calculateBadges({
    required List<Session> sessions,
    required int streak,
    required int totalMinutes,
  }) {
    // 1. Night Owl: Session between 10PM (22) and 4AM (4)
    bool isNightOwl = sessions.any((s) {
      final h = s.timestamp.hour;
      return h >= 22 || h < 4;
    });

    // 2. Early Bird: Session between 4AM and 8AM
    bool isEarlyBird = sessions.any((s) {
      final h = s.timestamp.hour;
      return h >= 4 && h < 8;
    });

    // 3. Marathoner: Single session > 60 mins (3600 seconds)
    bool isMarathoner = sessions.any((s) => s.duration >= 3600);

    // 4. Weekender: Session on Saturday or Sunday
    bool isWeekender = sessions.any((s) {
      final d = s.timestamp.weekday;
      return d == DateTime.saturday || d == DateTime.sunday;
    });

    // 5. Dedicated: 10+ sessions
    bool isDedicated = sessions.length >= 10;

    return [
      BadgeData(
        id: 'first_step',
        title: 'Start',
        description: 'Complete your first focus session.',
        icon: Icons.flag_rounded,
        color: Colors.blueAccent,
        isUnlocked: sessions.isNotEmpty,
      ),
      BadgeData(
        id: 'streak_3',
        title: 'On Fire',
        description: 'Reach a 3-day streak.',
        icon: Icons.local_fire_department_rounded,
        color: Colors.orangeAccent,
        isUnlocked: streak >= 3,
      ),
      BadgeData(
        id: 'streak_7',
        title: 'Unstop',
        description: 'Reach a 7-day streak.',
        icon: Icons.bolt_rounded,
        color: Colors.yellow,
        isUnlocked: streak >= 7,
      ),
      BadgeData(
        id: 'night_owl',
        title: 'Night Owl',
        description: 'Complete a session between 10 PM and 4 AM.',
        icon: Icons.nightlight_round,
        color: Colors.indigoAccent,
        isUnlocked: isNightOwl,
      ),
      BadgeData(
        id: 'early_bird',
        title: 'Early Bird',
        description: 'Complete a session between 4 AM and 8 AM.',
        icon: Icons.wb_sunny_rounded,
        color: Colors.amber,
        isUnlocked: isEarlyBird,
      ),
      BadgeData(
        id: 'marathoner',
        title: 'Marathon',
        description: 'Focus for over 60 minutes in a single session.',
        icon: Icons.timer_rounded,
        color: Colors.redAccent,
        isUnlocked: isMarathoner,
      ),
      BadgeData(
        id: 'zen_master',
        title: 'Zen',
        description: 'Accumulate 1000 minutes of total focus time.',
        icon: Icons.self_improvement_rounded,
        color: Colors.purpleAccent,
        isUnlocked: totalMinutes >= 1000,
      ),
      BadgeData(
        id: 'weekender',
        title: 'Weekend',
        description: 'Complete a session on a weekend.',
        icon: Icons.weekend_rounded,
        color: Colors.tealAccent,
        isUnlocked: isWeekender,
      ),
      BadgeData(
        id: 'dedicated',
        title: 'Dedicated',
        description: 'Complete 10 total sessions.',
        icon: CupertinoIcons.star_fill,
        color: Colors.pinkAccent,
        isUnlocked: isDedicated,
      ),
    ];
  }
}
