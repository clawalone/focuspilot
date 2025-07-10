import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/todo.dart';
import '../services/database_service.dart';
import '../theme/app_theme.dart';
import '../screens/todo_list_screen.dart';

class QuickTasksCard extends StatefulWidget {
  const QuickTasksCard({super.key});

  @override
  State<QuickTasksCard> createState() => _QuickTasksCardState();
}

class _QuickTasksCardState extends State<QuickTasksCard> {
  List<Todo> _topTasks = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadTasks();
  }

  Future<void> _loadTasks() async {
    final todos = await DatabaseService.instance.readAllTodos();
    final uncompleted = todos.where((t) => !t.isCompleted).take(3).toList();

    if (mounted) {
      setState(() {
        _topTasks = uncompleted;
        _isLoading = false;
      });
    }
  }

  Future<void> _toggleTask(Todo todo) async {
    final updated = todo.copyWith(isCompleted: !todo.isCompleted);
    await DatabaseService.instance.updateTodo(updated);
    _loadTasks(); // Refresh list to remove completed
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const SizedBox.shrink();

    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Column(
      children: [
        // Header Row
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4.0, vertical: 8.0),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Up Next',
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
              ),
              GestureDetector(
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const TodoListScreen(),
                    ),
                  ).then((_) => _loadTasks()); // Refresh on return
                },
                child: Text(
                  _topTasks.isEmpty ? 'Add Task' : 'See All',
                  style: GoogleFonts.outfit(
                    color: AppTheme.primaryColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),
        ),

        // Task List
        _topTasks.isEmpty
            ? Container(
                decoration: BoxDecoration(
                  color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.05),
                      blurRadius: 15,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(24.0),
                child: Center(
                  child: Column(
                    children: [
                      Icon(
                        CupertinoIcons.check_mark_circled,
                        size: 48,
                        color: isDark ? Colors.white24 : Colors.black12,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        "No upcoming tasks",
                        style: TextStyle(
                          color: isDark ? Colors.white38 : Colors.black38,
                          fontSize: 14,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            : Column(
                children: _topTasks
                    .map((task) => _buildMiniTaskItem(task, isDark))
                    .toList(),
              ),
      ],
    );
  }

  Widget _buildMiniTaskItem(Todo todo, bool isDark) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(isDark ? 0.2 : 0.05),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _toggleTask(todo),
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            child: Row(
              children: [
                Container(
                  width: 24,
                  height: 24,
                  decoration: BoxDecoration(
                    color: Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isDark ? Colors.white38 : Colors.black26,
                      width: 2,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Text(
                    todo.title,
                    style: GoogleFonts.outfit(
                      fontSize: 16,
                      color: isDark ? Colors.white : Colors.black87,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
