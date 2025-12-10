class Todo {
  final int? id;
  final String title;
  final bool isCompleted;
  final DateTime createdTime;

  Todo({
    this.id,
    required this.title,
    this.isCompleted = false,
    required this.createdTime,
  });

  Todo copyWith({
    int? id,
    String? title,
    bool? isCompleted,
    DateTime? createdTime,
  }) {
    return Todo(
      id: id ?? this.id,
      title: title ?? this.title,
      isCompleted: isCompleted ?? this.isCompleted,
      createdTime: createdTime ?? this.createdTime,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'isCompleted': isCompleted ? 1 : 0,
      'createdTime': createdTime.toIso8601String(),
    };
  }

  factory Todo.fromMap(Map<String, dynamic> map) {
    return Todo(
      id: map['id'],
      title: map['title'],
      isCompleted: map['isCompleted'] == 1,
      createdTime: DateTime.parse(map['createdTime']),
    );
  }
}
