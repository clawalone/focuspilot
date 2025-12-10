import 'package:flutter/material.dart';
import '../models/session.dart';
import '../theme/app_theme.dart';

class SessionsScreen extends StatelessWidget {
  final List<Session> sessions;

  const SessionsScreen({super.key, required this.sessions});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.statsDarkBackground,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        title: const Text(
          'history',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: sessions.isEmpty
          ? const Center(
              child: Text(
                'No sessions yet',
                style: TextStyle(color: Colors.grey),
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.all(24),
              itemCount: sessions.length,
              itemBuilder: (context, index) {
                final session = sessions[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 16),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.statsCardBackground,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: _getColorForCategory(
                            session.category,
                          ).withOpacity(0.2),
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          Icons.timer,
                          color: _getColorForCategory(session.category),
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              session.category,
                              style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              '${session.timestamp.day}/${session.timestamp.month}/${session.timestamp.year} • ${session.appsLimitedCount} apps blocked',
                              style: const TextStyle(
                                color: AppTheme.statsTextGrey,
                                fontSize: 12,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Text(
                        '${(session.duration / 60).toStringAsFixed(0)}m',
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 18,
                        ),
                      ),
                    ],
                  ),
                );
              },
            ),
    );
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
}
