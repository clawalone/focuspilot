class Session {
  final int? id;
  final String category;
  final int duration; // total duration in seconds
  final DateTime timestamp;
  final int appsLimitedCount;
  final int workDuration; // in seconds
  final int reviseDuration; // in seconds
  final int breakDuration; // in seconds
  final int sessionsCount;
  final bool isReviseBefore;
  final String? note;

  Session({
    this.id,
    required this.category,
    required this.duration,
    required this.timestamp,
    required this.appsLimitedCount,
    this.workDuration = 0,
    this.reviseDuration = 0,
    this.breakDuration = 0,
    this.sessionsCount = 1,
    this.isReviseBefore = true,
    this.note,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'apps_limited_count': appsLimitedCount,
      'work_duration': workDuration,
      'revise_duration': reviseDuration,
      'break_duration': breakDuration,
      'sessions_count': sessionsCount,
      'is_revise_before': isReviseBefore ? 1 : 0,
      'note': note,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      category: map['category'],
      duration: map['duration'],
      timestamp: DateTime.parse(map['timestamp']),
      appsLimitedCount: map['apps_limited_count'] ?? 0,
      workDuration: map['work_duration'] ?? 0,
      reviseDuration: map['revise_duration'] ?? 0,
      breakDuration: map['break_duration'] ?? 0,
      sessionsCount: map['sessions_count'] ?? 1,
      isReviseBefore: (map['is_revise_before'] ?? 1) == 1,
      note: map['note'],
    );
  }
}
