import 'dart:ui';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

import '../models/todo.dart';
import '../services/database_service.dart';
import '../services/notification_service.dart';
import '../services/reminder_service.dart';
import '../theme/app_theme.dart';
import 'create_task_screen.dart';
import 'package:intl/intl.dart';
import '../widgets/animated_background.dart';
import '../services/firestore_service.dart';

class TodoListScreen extends StatefulWidget {
  const TodoListScreen({super.key});

  @override
  State<TodoListScreen> createState() => _TodoListScreenState();
}

class _TodoListScreenState extends State<TodoListScreen>
    with SingleTickerProviderStateMixin {
  List<Todo> _todos = [];
  bool _isLoading = true;
  final TextEditingController _taskController = TextEditingController();
  late TabController _tabController;
  bool _showCompleted = true;
  bool _isCompletedExpanded = true;
  String _sortBy = 'order'; // 'order', 'priority', 'date'
  final Set<int> _expandedTodoIds = {};

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _refreshTodos();
    // Listen for database changes (e.g. from notifications)
    DatabaseService.instance.changeNotifier.addListener(_onDatabaseChanged);
  }

  void _onDatabaseChanged() {
    if (mounted) {
      _refreshTodos(silent: true);
    }
  }

  @override
  void dispose() {
    DatabaseService.instance.changeNotifier.removeListener(_onDatabaseChanged);
    _tabController.dispose();
    _taskController.dispose();
    super.dispose();
  }

  Future<void> _refreshTodos({bool silent = false}) async {
    if (!silent) setState(() => _isLoading = true);
    final todos = await DatabaseService.instance.readAllTodos();
    if (mounted) {
      setState(() {
        _todos = todos;
        _isLoading = false;
      });
    }
  }

  Future<void> _updateTodo(Todo todo) async {
    final oldTodo = _todos.firstWhere(
      (t) => t.id == todo.id,
      orElse: () => todo,
    );

    setState(() {
      int idx = _todos.indexWhere((t) => t.id == todo.id);
      if (idx != -1) {
        _todos[idx] = todo;
      }
    });

    await DatabaseService.instance.updateTodo(todo);

    if (todo.id != null) {
      // Only act on reminders if completion status or reminder time changed
      bool statusChanged = oldTodo.isCompleted != todo.isCompleted;
      bool timeChanged = oldTodo.reminderTime != todo.reminderTime;

      if (todo.isCompleted && statusChanged) {
        await NotificationService().cancelNotification(todo.id!);
        await ReminderService().cancelReminder(todo.id!);
      } else if (!todo.isCompleted && (statusChanged || timeChanged)) {
        if (todo.reminderTime != null) {
          try {
            await ReminderService().scheduleMissionReminder(
              todo: todo,
              scheduledDate: todo.reminderTime!,
            );
          } catch (e) {
            debugPrint('Error scheduling mission reminder: $e');
          }
        } else if (oldTodo.reminderTime != null) {
          // Time was removed
          await ReminderService().cancelReminder(todo.id!);
        }
      }
    }

    // Sync to Cloud for Pro Reminders
    await FirestoreService.instance.syncTodo(todo);

    _refreshTodos(silent: true);
  }

  Future<void> _pickReminderTime(Todo todo) async {
    final TimeOfDay? picked = await showTimePicker(
      context: context,
      initialTime: todo.reminderTime != null
          ? TimeOfDay.fromDateTime(todo.reminderTime!)
          : TimeOfDay.now(),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      final now = DateTime.now();
      final reminderDateTime = DateTime(
        todo.dueDate?.year ?? now.year,
        todo.dueDate?.month ?? now.month,
        todo.dueDate?.day ?? now.day,
        picked.hour,
        picked.minute,
      );

      if (reminderDateTime.isBefore(now.subtract(const Duration(minutes: 1)))) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Cannot set a mission in the past')),
          );
        }
        return;
      }

      await _updateTodo(todo.copyWith(reminderTime: reminderDateTime));
    }
  }

  Future<void> _deleteTodo(int id) async {
    setState(() {
      _todos.removeWhere((t) => t.id == id);
    });

    await NotificationService().cancelNotification(id);
    await DatabaseService.instance.deleteTodo(id);
    _refreshTodos(silent: true);
  }

  void _onReorder(int oldIndex, int newIndex, List<Todo> filteredTodos) async {
    if (newIndex > oldIndex) newIndex -= 1;

    setState(() {
      // 1. Move item locally in the filtered list
      final item = filteredTodos.removeAt(oldIndex);
      filteredTodos.insert(newIndex, item);

      // 2. Update orderIndex and sync with global _todos list
      for (int i = 0; i < filteredTodos.length; i++) {
        final updated = filteredTodos[i].copyWith(orderIndex: i);
        filteredTodos[i] = updated;

        // Find and replace in global list to ensure consistency across tabs
        int mainIdx = _todos.indexWhere((t) => t.id == updated.id);
        if (mainIdx != -1) {
          _todos[mainIdx] = updated;
        }
      }

      // 3. Force sort mode to 'order' so manual changes aren't clobbered by priority
      _sortBy = 'order';
    });

    // 4. Persistence in background using batch for performance
    await DatabaseService.instance.updateTodosBatch(filteredTodos);

    // 5. Silent refresh to ensure database consistency without UI flicker
    _refreshTodos(silent: true);
  }

  List<Todo> _getFilteredTodos(int tabIndex) {
    DateTime now = DateTime.now();
    DateTime today = DateTime(now.year, now.month, now.day);
    DateTime tomorrow = today.add(const Duration(days: 1));

    Iterable<Todo> filtered;
    if (tabIndex == 1) {
      // Today
      filtered = _todos.where(
        (t) =>
            t.dueDate != null &&
            DateTime(
              t.dueDate!.year,
              t.dueDate!.month,
              t.dueDate!.day,
            ).isAtSameMomentAs(today),
      );
    } else if (tabIndex == 2) {
      // Tomorrow
      filtered = _todos.where(
        (t) =>
            t.dueDate != null &&
            DateTime(
              t.dueDate!.year,
              t.dueDate!.month,
              t.dueDate!.day,
            ).isAtSameMomentAs(tomorrow),
      );
    } else {
      // Inbox (All tasks) - Index 0
      filtered = _todos;
    }

    List<Todo> list = filtered.toList();

    if (!_showCompleted) {
      list = list.where((t) => !t.isCompleted).toList();
    }

    if (_sortBy == 'priority') {
      list.sort((a, b) => b.priority.compareTo(a.priority));
    } else if (_sortBy == 'date') {
      list.sort(
        (a, b) =>
            (a.dueDate ?? DateTime(0)).compareTo(b.dueDate ?? DateTime(0)),
      );
    } else {
      list.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));
    }

    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.statsDarkBackground,
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(),
              _buildTabBar(),
              Expanded(
                child: TabBarView(
                  controller: _tabController,
                  children: [
                    _buildTaskList(0),
                    _buildTaskList(1),
                    _buildTaskList(2),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
      floatingActionButton: _buildFAB(),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 16, 16, 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            'Tasks',
            style: GoogleFonts.outfit(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: isDark ? Colors.white : Colors.black,
            ),
          ),
          Row(
            children: [
              PopupMenuButton<String>(
                icon: Icon(
                  Icons.more_vert,
                  color: isDark ? Colors.white70 : Colors.black54,
                ),
                color: isDark ? const Color(0xFF1E1E2C) : Colors.white,
                onSelected: (value) {
                  setState(() {
                    if (value == 'hide_completed') {
                      _showCompleted = !_showCompleted;
                    } else {
                      _sortBy = value;
                    }
                  });
                },
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'date',
                    child: Text(
                      'Sort by Due Date',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'priority',
                    child: Text(
                      'Sort by Priority',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  PopupMenuItem(
                    value: 'order',
                    child: Text(
                      'Manual Ordering',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'hide_completed',
                    child: Text(
                      _showCompleted ? 'Hide Completed' : 'Show Completed',
                      style: GoogleFonts.outfit(
                        color: isDark ? Colors.white : Colors.black,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTabBar() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TabBar(
      controller: _tabController,
      isScrollable: true,
      labelColor: AppTheme.primaryColor,
      unselectedLabelColor: isDark ? Colors.white38 : Colors.black38,
      indicatorColor: Colors.transparent,
      dividerColor: Colors.transparent,
      labelStyle: GoogleFonts.outfit(fontSize: 18, fontWeight: FontWeight.bold),
      tabs: const [
        Tab(text: 'Inbox'),
        Tab(text: 'Today'),
        Tab(text: 'Tomorrow'),
      ],
    );
  }

  Widget _buildTaskList(int index) {
    final filtered = _getFilteredTodos(index);
    final activeTasks = filtered.where((t) => !t.isCompleted).toList();
    final completedTasks = filtered.where((t) => t.isCompleted).toList();

    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    if (filtered.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              CupertinoIcons.checkmark_seal,
              size: 64,
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white10
                  : Colors.black12,
            ),
            const SizedBox(height: 16),
            Text(
              'No tasks here',
              style: GoogleFonts.outfit(
                color: Theme.of(context).brightness == Brightness.dark
                    ? Colors.white38
                    : Colors.black38,
              ),
            ),
          ],
        ),
      );
    }

    String headerText = '';
    if (index == 1)
      headerText = 'Today';
    else if (index == 2)
      headerText = 'Tomorrow';
    else
      headerText = 'Inbox';

    return ListView(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      children: [
        if (activeTasks.isNotEmpty) ...[
          _buildSectionHeader(headerText),
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: activeTasks.length,
            onReorder: (oldIndex, newIndex) =>
                _onReorder(oldIndex, newIndex, activeTasks),
            itemBuilder: (context, idx) {
              final todo = activeTasks[idx];
              return _buildTaskTile(todo, Key('todo_${todo.id}'));
            },
          ),
        ],
        if (completedTasks.isNotEmpty && _showCompleted) ...[
          _buildSectionHeader(
            'Completed',
            isCollapsible: true,
            isExpanded: _isCompletedExpanded,
            onToggle: () =>
                setState(() => _isCompletedExpanded = !_isCompletedExpanded),
          ),
          if (_isCompletedExpanded)
            ...completedTasks.map(
              (todo) => _buildTaskTile(todo, Key('todo_${todo.id}')),
            ),
        ],
      ],
    );
  }

  Widget _buildSectionHeader(
    String title, {
    bool isCollapsible = false,
    bool isExpanded = true,
    VoidCallback? onToggle,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return GestureDetector(
      onTap: isCollapsible ? onToggle : null,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              title,
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white38 : Colors.black38,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
            Icon(
              isExpanded
                  ? Icons.keyboard_arrow_down
                  : Icons.keyboard_arrow_right,
              color: isDark ? Colors.white38 : Colors.black38,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTaskTile(Todo todo, Key key) {
    final isExpanded = _expandedTodoIds.contains(todo.id);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final cardContent = Dismissible(
      key: Key('dismiss_${todo.id}'),
      background: _buildSwipeBackground(true),
      secondaryBackground: _buildSwipeBackground(false),
      confirmDismiss: (direction) async {
        if (direction == DismissDirection.startToEnd) {
          _updateTodo(todo.copyWith(isCompleted: !todo.isCompleted));
          return false;
        } else {
          await _pickDateForTodo(todo);
          return false;
        }
      },
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Custom Checkbox
                    GestureDetector(
                      onTap: () => _updateTodo(
                        todo.copyWith(isCompleted: !todo.isCompleted),
                      ),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        width: 24,
                        height: 24,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: todo.isCompleted
                              ? AppTheme.primaryColor
                              : Colors.transparent,
                          border: Border.all(
                            color: todo.isCompleted
                                ? AppTheme.primaryColor
                                : (isDark ? Colors.white38 : Colors.black38),
                            width: 2,
                          ),
                        ),
                        child: todo.isCompleted
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                      ),
                    ),
                    const SizedBox(width: 16),
                    // Task Title and Touch Area
                    Expanded(
                      child: GestureDetector(
                        onTap: () {
                          setState(() {
                            if (isExpanded) {
                              _expandedTodoIds.remove(todo.id);
                            } else {
                              _expandedTodoIds.add(todo.id!);
                            }
                          });
                        },
                        onLongPress: () => _showEditTaskDialog(todo),
                        behavior: HitTestBehavior.opaque,
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    todo.title,
                                    style: GoogleFonts.outfit(
                                      color: todo.isCompleted
                                          ? (isDark
                                                ? Colors.white38
                                                : Colors.black38)
                                          : (isDark
                                                ? Colors.white
                                                : Colors.black),
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                      decoration: todo.isCompleted
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  if (!isExpanded &&
                                      todo.dueDate != null &&
                                      !todo.isCompleted) ...[
                                    const SizedBox(height: 4),
                                    Row(
                                      children: [
                                        Text(
                                          _formatDueDate(todo.dueDate!),
                                          style: GoogleFonts.outfit(
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.black38,
                                            fontSize: 12,
                                          ),
                                        ),
                                        if (todo.reminderTime != null) ...[
                                          const SizedBox(width: 8),
                                          Icon(
                                            CupertinoIcons.bell_fill,
                                            size: 10,
                                            color: AppTheme.primaryColor,
                                          ),
                                        ],
                                      ],
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (!todo.isCompleted)
                              IconButton(
                                icon: Icon(
                                  todo.reminderTime != null
                                      ? CupertinoIcons.bell_fill
                                      : CupertinoIcons.bell,
                                  size: 18,
                                  color: todo.reminderTime != null
                                      ? AppTheme.primaryColor
                                      : (isDark
                                            ? Colors.white24
                                            : Colors.black26),
                                ),
                                onPressed: () => _pickReminderTime(todo),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                // Expanded Details
                if (isExpanded) ...[
                  const SizedBox(height: 12),
                  Divider(color: isDark ? Colors.white10 : Colors.black12),
                  if (todo.dueDate != null && !todo.isCompleted) ...[
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        const Icon(
                          CupertinoIcons.calendar,
                          size: 14,
                          color: AppTheme.primaryColor,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          _formatDueDate(todo.dueDate!),
                          style: GoogleFonts.outfit(
                            color: isDark ? Colors.white70 : Colors.black87,
                            fontSize: 13,
                          ),
                        ),
                        if (todo.reminderTime != null) ...[
                          const SizedBox(width: 16),
                          const Icon(
                            CupertinoIcons.bell_fill,
                            size: 14,
                            color: AppTheme.primaryColor,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            DateFormat('h:mm a').format(todo.reminderTime!),
                            style: GoogleFonts.outfit(
                              color: isDark ? Colors.white70 : Colors.black87,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                  if (todo.isProgressTracked &&
                      todo.progressType == 'percentage' &&
                      !todo.isCompleted) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: isDark
                            ? Colors.black12
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          GestureDetector(
                            onTap: () {
                              final newVal = (todo.progress - 0.1).clamp(
                                0.0,
                                1.0,
                              );
                              _updateTodo(todo.copyWith(progress: newVal));
                            },
                            child: Icon(
                              CupertinoIcons.minus_circle_fill,
                              color: isDark
                                  ? Colors.white.withOpacity(0.3)
                                  : Colors.black.withOpacity(0.3),
                              size: 28,
                            ),
                          ),
                          Expanded(
                            child: SliderTheme(
                              data: SliderTheme.of(context).copyWith(
                                trackHeight: 6,
                                thumbShape: const RoundSliderThumbShape(
                                  enabledThumbRadius: 8,
                                  elevation: 0,
                                ),
                                overlayShape: const RoundSliderOverlayShape(
                                  overlayRadius: 0,
                                ),
                                activeTrackColor: AppTheme.primaryColor,
                                inactiveTrackColor: isDark
                                    ? Colors.white10
                                    : Colors.grey.withOpacity(0.2),
                                thumbColor: isDark
                                    ? Colors.white
                                    : Colors.white,
                              ),
                              child: Slider(
                                value: todo.progress,
                                onChanged: (val) {
                                  setState(() {
                                    int idx = _todos.indexWhere(
                                      (t) => t.id == todo.id,
                                    );
                                    if (idx != -1) {
                                      _todos[idx] = _todos[idx].copyWith(
                                        progress: val,
                                      );
                                    }
                                  });
                                },
                                onChangeEnd: (val) {
                                  _updateTodo(todo.copyWith(progress: val));
                                },
                              ),
                            ),
                          ),
                          GestureDetector(
                            onTap: () {
                              final newVal = (todo.progress + 0.1).clamp(
                                0.0,
                                1.0,
                              );
                              _updateTodo(todo.copyWith(progress: newVal));
                            },
                            child: const Icon(
                              CupertinoIcons.plus_circle_fill,
                              color: AppTheme.primaryColor,
                              size: 28,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Container(
                            width: 44,
                            alignment: Alignment.centerRight,
                            child: Text(
                              '${(todo.progress * 100).toInt()}%',
                              style: GoogleFonts.outfit(
                                color: isDark ? Colors.white : Colors.black,
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ],
              ],
            ),
          ),
        ],
      ),
    );

    if (isDark) {
      return Container(
        key: key,
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.white.withOpacity(0.1), width: 1),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: BackdropFilter(
            filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
            child: Container(
              color: AppTheme.statsCardBackground.withOpacity(0.7),
              child: cardContent,
            ),
          ),
        ),
      );
    }

    // Light Mode (Matches Settings Screen style)
    return Container(
      key: key,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: cardContent,
    );
  }

  Future<void> _pickDateForTodo(Todo todo) async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: todo.dueDate ?? now,
      firstDate: now.subtract(const Duration(days: 365)),
      lastDate: now.add(const Duration(days: 365 * 5)),
      builder: (context, child) {
        return Theme(
          data: ThemeData.dark().copyWith(
            colorScheme: const ColorScheme.dark(
              primary: AppTheme.primaryColor,
              onPrimary: Colors.white,
              surface: Color(0xFF1E1E2C),
              onSurface: Colors.white,
            ),
          ),
          child: child!,
        );
      },
    );

    if (picked != null) {
      _updateTodo(todo.copyWith(dueDate: picked));
    }
  }

  void _showEditTaskDialog(Todo todo) {
    _taskController.text = todo.title;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.of(context).viewInsets.bottom,
        ),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: const BoxDecoration(
            color: Color(0xFF1E1E2C),
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: _taskController,
                autofocus: true,
                style: GoogleFonts.outfit(color: Colors.white, fontSize: 18),
                decoration: InputDecoration(
                  hintText: 'Task title',
                  hintStyle: GoogleFonts.outfit(color: Colors.white24),
                  border: InputBorder.none,
                ),
                onSubmitted: (val) {
                  _updateTodo(todo.copyWith(title: val));
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    icon: const Icon(
                      CupertinoIcons.trash,
                      color: Colors.redAccent,
                    ),
                    onPressed: () {
                      _deleteTodo(todo.id!);
                      Navigator.pop(context);
                    },
                  ),
                  Row(
                    children: [
                      TextButton(
                        onPressed: () => Navigator.pop(context),
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.outfit(color: Colors.white38),
                        ),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: () {
                          _updateTodo(
                            todo.copyWith(title: _taskController.text),
                          );
                          Navigator.pop(context);
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.primaryColor,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        child: Text(
                          'Save',
                          style: GoogleFonts.outfit(color: Colors.white),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatDueDate(DateTime date) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final inputDate = DateTime(date.year, date.month, date.day);

    if (inputDate.isAtSameMomentAs(today)) return 'Today';
    if (inputDate.isAtSameMomentAs(today.add(const Duration(days: 1)))) {
      return 'Tomorrow';
    }
    return DateFormat('MMM d').format(date);
  }

  Widget _buildSwipeBackground(bool isLeft) {
    return Container(
      color: isLeft
          ? Colors.green.withOpacity(0.2)
          : Colors.red.withOpacity(0.2),
      alignment: isLeft ? Alignment.centerLeft : Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Icon(
        isLeft ? Icons.check_circle_outline : Icons.calendar_today,
        color: isLeft ? Colors.green : AppTheme.primaryColor,
      ),
    );
  }

  Widget _buildFAB() {
    return FloatingActionButton(
      onPressed: () async {
        final result = await Navigator.push(
          context,
          CupertinoPageRoute(builder: (context) => const CreateTaskScreen()),
        );
        if (result == true) {
          _refreshTodos();
        }
      },
      backgroundColor: AppTheme.primaryColor,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: const Icon(Icons.add, color: Colors.white),
    );
  }
}
