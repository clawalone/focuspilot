class Todo {
  final int? id;
  final String title;
  final bool isCompleted;
  final DateTime createdTime;
  final DateTime? dueDate;
  final double progress; // 0.0 to 1.0
  final int priority; // 0: low, 1: medium, 2: high
  final int orderIndex;
  final String category;

  // New fields for Version 7
  final DateTime? reminderTime;
  final String repeatType; // 'none', 'daily', 'weekly', 'monthly'
  final bool isProgressTracked;
  final String progressType; // 'percentage', 'subtasks'
  final DateTime? startTime;
  final String note;
  final String? subTasks; // JSON string for subtasks list

  Todo({
    this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdTime,
    this.dueDate,
    this.progress = 0.0,
    this.priority = 0,
    this.orderIndex = 0,
    this.category = 'Tasks',
    this.reminderTime,
    this.repeatType = 'none',
    this.isProgressTracked = false,
    this.progressType = 'percentage',
    this.startTime,
    this.note = '',
    this.subTasks,
  });

  Todo copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    DateTime? createdTime,
    DateTime? dueDate,
    double? progress,
    int? priority,
    int? orderIndex,
    String? category,
    DateTime? reminderTime,
    String? repeatType,
    bool? isProgressTracked,
    String? progressType,
    DateTime? startTime,
    String? note,
    String? subTasks,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdTime: createdTime ?? this.createdTime,
      dueDate: dueDate ?? this.dueDate,
      progress: progress ?? this.progress,
      priority: priority ?? this.priority,
      orderIndex: orderIndex ?? this.orderIndex,
      category: category ?? this.category,
      reminderTime: reminderTime ?? this.reminderTime,
      repeatType: repeatType ?? this.repeatType,
      isProgressTracked: isProgressTracked ?? this.isProgressTracked,
      progressType: progressType ?? this.progressType,
      startTime: startTime ?? this.startTime,
      note: note ?? this.note,
      subTasks: subTasks ?? this.subTasks,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'createdTime': createdTime.toIso8601String(),
      'dueDate': dueDate?.toIso8601String(),
      'progress': progress,
      'priority': priority,
      'orderIndex': orderIndex,
      'category': category,
      'reminderTime': reminderTime?.toIso8601String(),
      'repeatType': repeatType,
      'isProgressTracked': isProgressTracked ? 1 : 0,
      'progressType': progressType,
      'startTime': startTime?.toIso8601String(),
      'note': note,
      'subTasks': subTasks,
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
      createdTime: DateTime.parse(map['createdTime']),
      dueDate: map['dueDate'] != null ? DateTime.parse(map['dueDate']) : null,
      progress: (map['progress'] ?? 0.0).toDouble(),
      priority: map['priority'] ?? 0,
      orderIndex: map['orderIndex'] ?? 0,
      category: map['category'] ?? 'Tasks',
      reminderTime: map['reminderTime'] != null
          ? DateTime.parse(map['reminderTime'])
          : null,
      repeatType: map['repeatType'] ?? 'none',
      isProgressTracked: map['isProgressTracked'] == 1,
      progressType: map['progressType'] ?? 'percentage',
      startTime: map['startTime'] != null
          ? DateTime.parse(map['startTime'])
          : null,
      note: map['note'] ?? '',
      subTasks: map['subTasks'],
    );
  }
}
