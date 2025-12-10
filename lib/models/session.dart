class Session {
  final int? id;
  final String category;
  final int duration; // in seconds
  final DateTime timestamp;
  final int appsLimitedCount;

  Session({
    this.id,
    required this.category,
    required this.duration,
    required this.timestamp,
    required this.appsLimitedCount,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'category': category,
      'duration': duration,
      'timestamp': timestamp.toIso8601String(),
      'apps_limited_count': appsLimitedCount,
    };
  }

  factory Session.fromMap(Map<String, dynamic> map) {
    return Session(
      id: map['id'],
      category: map['category'],
      duration: map['duration'],
      timestamp: DateTime.parse(map['timestamp']),
      appsLimitedCount: map['apps_limited_count'],
    );
  }
}
