import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../models/todo.dart';

import '../services/database_service.dart';
import '../services/reminder_service.dart'; // Added ReminderService import

import '../theme/app_theme.dart';
import '../widgets/animated_background.dart';

class CreateTaskScreen extends StatefulWidget {
  const CreateTaskScreen({super.key});

  @override
  State<CreateTaskScreen> createState() => _CreateTaskScreenState();
}

class _CreateTaskScreenState extends State<CreateTaskScreen> {
  final TextEditingController _titleController = TextEditingController();
  final TextEditingController _noteController = TextEditingController();
  final List<TextEditingController> _subTaskControllers = [];

  DateTime? _dueDate = DateTime.now();
  DateTime? _startTime;
  DateTime? _reminderTime;
  String _repeatType = 'None';
  String _category = 'Unlabelled';
  int _priority = 0;
  bool _isProgressTracked = true;
  String _progressType = 'Percentage';

  @override
  void dispose() {
    _titleController.dispose();
    _noteController.dispose();
    for (var controller in _subTaskControllers) {
      controller.dispose();
    }
    super.dispose();
  }

  void _addSubTask() {
    setState(() {
      _subTaskControllers.add(TextEditingController());
    });
  }

  void _removeSubTask(int index) {
    setState(() {
      _subTaskControllers[index].dispose();
      _subTaskControllers.removeAt(index);
    });
  }

  Future<void> _saveTask({bool popAfterSave = true}) async {
    final title = _titleController.text.trim();
    if (title.isEmpty) return;

    final subTasks = _subTaskControllers
        .map((c) => c.text.trim())
        .where((text) => text.isNotEmpty)
        .toList();

    final todo = Todo(
      title: title,
      createdTime: DateTime.now(),
      dueDate: _dueDate,
      priority: _priority,
      category: _category,
      reminderTime: _reminderTime,
      repeatType: _repeatType.toLowerCase(),
      isProgressTracked: _isProgressTracked,
      progressType: _progressType.toLowerCase(),
      startTime: _startTime,
      note: _noteController.text.trim(),
      subTasks: subTasks.isNotEmpty ? jsonEncode(subTasks) : null,
    );

    final createdTodo = await DatabaseService.instance.createTodo(todo);

    // Schedule mission reminder if set
    if (_reminderTime != null && createdTodo.id != null) {
      try {
        await ReminderService().scheduleMissionReminder(
          todo: createdTodo,
          scheduledDate: _reminderTime!,
        );
      } catch (e) {
        debugPrint('Error scheduling mission reminder: $e');
      }
    }

    if (mounted && popAfterSave) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBackground(
        child: SafeArea(
          child: Column(
            children: [
              _buildHeader(),
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.symmetric(horizontal: 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 24),
                      _buildTitleInput(),
                      const SizedBox(height: 16),
                      _buildSubTaskList(),
                      const SizedBox(height: 32),
                      _buildDateSelector(),
                      const SizedBox(height: 32),
                      _buildOptionsList(),
                      const SizedBox(height: 32),
                      _buildProgressTracking(),
                      const SizedBox(height: 32),
                      _buildNoteInput(),
                      const SizedBox(height: 100),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          IconButton(
            icon: Icon(
              CupertinoIcons.arrow_left,
              color: isDark ? Colors.white : Colors.black,
            ),
            onPressed: () => Navigator.pop(context),
          ),
          Row(
            children: [
              IconButton(
                icon: Icon(
                  CupertinoIcons.flag_fill,
                  color: _priority == 2
                      ? Colors.red
                      : (isDark ? Colors.white60 : Colors.black54),
                ),
                onPressed: () {
                  setState(() {
                    _priority = (_priority + 1) % 3;
                  });
                },
              ),
              IconButton(
                icon: Icon(
                  CupertinoIcons.list_bullet_indent,
                  color: isDark ? Colors.white60 : Colors.black54,
                ),
                onPressed: _addSubTask,
              ),
              IconButton(
                icon: Icon(
                  Icons.save_rounded,
                  color: isDark ? Colors.white : AppTheme.primaryColor,
                ),
                onPressed: _saveTask,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return TextField(
      controller: _titleController,
      style: GoogleFonts.outfit(
        fontSize: 28,
        fontWeight: FontWeight.w600,
        color: isDark ? Colors.white : Colors.black,
      ),
      decoration: InputDecoration(
        hintText: 'New task',
        hintStyle: GoogleFonts.outfit(
          color: isDark ? Colors.white24 : Colors.black26,
        ),
        border: InputBorder.none,
      ),
    );
  }

  Widget _buildSubTaskList() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      children: [
        ...List.generate(_subTaskControllers.length, (index) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Icon(
                  CupertinoIcons.list_bullet_indent,
                  color: isDark ? Colors.white24 : Colors.black26,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _subTaskControllers[index],
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white70 : Colors.black87,
                      fontSize: 16,
                    ),
                    decoration: InputDecoration(
                      hintText: 'Sub-task details...',
                      hintStyle: GoogleFonts.outfit(
                        color: isDark ? Colors.white12 : Colors.black12,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                  icon: Icon(
                    CupertinoIcons.xmark_circle,
                    color: isDark ? Colors.white24 : Colors.black26,
                    size: 20,
                  ),
                  onPressed: () => _removeSubTask(index),
                ),
              ],
            ),
          );
        }),
        GestureDetector(
          onTap: _addSubTask,
          child: Row(
            children: [
              Icon(
                CupertinoIcons.list_bullet_indent,
                color: isDark ? Colors.white24 : Colors.black26,
                size: 20,
              ),
              const SizedBox(width: 12),
              Text(
                'Add sub-task...',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white24 : Colors.black26,
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildDateSelector() {
    return Row(
      children: [
        _buildDateButton(
          'Today',
          _dueDate != null && _isSameDay(_dueDate!, DateTime.now()),
        ),
        const SizedBox(width: 12),
        _buildDateButton(
          'Tomorrow',
          _dueDate != null &&
              _isSameDay(
                _dueDate!,
                DateTime.now().add(const Duration(days: 1)),
              ),
        ),
        const SizedBox(width: 12),
        _buildDateButton(
          'Custom',
          _dueDate != null &&
              !_isSameDay(_dueDate!, DateTime.now()) &&
              !_isSameDay(
                _dueDate!,
                DateTime.now().add(const Duration(days: 1)),
              ),
        ),
      ],
    );
  }

  bool _isSameDay(DateTime a, DateTime b) {
    return a.year == b.year && a.month == b.month && a.day == b.day;
  }

  void _applyDueDate(DateTime date) {
    setState(() {
      _dueDate = date;
      if (_reminderTime != null) {
        _reminderTime = DateTime(
          date.year,
          date.month,
          date.day,
          _reminderTime!.hour,
          _reminderTime!.minute,
        );
      }
    });
  }

  Widget _buildDateButton(String label, bool isSelected) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Expanded(
      child: GestureDetector(
        onTap: () {
          if (label == 'Today') {
            _applyDueDate(DateTime.now());
          } else if (label == 'Tomorrow') {
            _applyDueDate(DateTime.now().add(const Duration(days: 1)));
          } else {
            _pickDueDate();
          }
        },
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: isSelected
                ? AppTheme.primaryColor
                : (isDark
                      ? Colors.white.withOpacity(0.05)
                      : Colors.black.withOpacity(0.05)),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: isSelected
                  ? Colors.transparent
                  : (isDark ? Colors.white10 : Colors.black12),
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected
                  ? Colors.white
                  : (isDark ? Colors.white60 : Colors.black54),
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _pickDueDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dueDate ?? DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) {
      _applyDueDate(picked);
    }
  }

  Widget _buildOptionsList() {
    return Column(
      children: [
        _buildOptionItem(
          icon: CupertinoIcons.clock,
          label: 'Set Time',
          value: _startTime == null
              ? null
              : '${_startTime!.hour}:${_startTime!.minute.toString().padLeft(2, '0')}',
          onTap: _pickStartTime,
        ),
        _buildOptionItem(
          icon: CupertinoIcons.tag,
          label: _category,
          onTap: _showCategoryPicker,
        ),
        _buildOptionItem(
          icon: CupertinoIcons.bell,
          label: 'Mission Reminder',
          value: _reminderTime == null
              ? 'None'
              : '${_reminderTime!.hour}:${_reminderTime!.minute.toString().padLeft(2, '0')}',
          onTap: _pickReminderTime,
        ),
        _buildOptionItem(
          icon: CupertinoIcons.repeat,
          label: 'Repeat',
          value: _repeatType,
          onTap: _showRepeatPicker,
        ),
      ],
    );
  }

  Widget _buildOptionItem({
    required IconData icon,
    required String label,
    String? value,
    VoidCallback? onTap,
  }) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.only(bottom: 24),
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: Row(
          children: [
            Icon(
              icon,
              color: isDark ? Colors.white70 : Colors.black87,
              size: 24,
            ),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(
                color: isDark ? Colors.white : Colors.black,
                fontSize: 16,
              ),
            ),
            const Spacer(),
            if (value != null)
              Text(
                value,
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 16,
                ),
              ),
            if (onTap != null && value == null && icon == CupertinoIcons.clock)
              Icon(
                CupertinoIcons.xmark,
                color: isDark ? Colors.white24 : Colors.black26,
                size: 16,
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _pickStartTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        final now = DateTime.now();
        _startTime = DateTime(
          now.year,
          now.month,
          now.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  Future<void> _pickReminderTime() async {
    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (time != null) {
      setState(() {
        final date = _dueDate ?? DateTime.now();
        _reminderTime = DateTime(
          date.year,
          date.month,
          date.day,
          time.hour,
          time.minute,
        );
      });
    }
  }

  void _showCategoryPicker() async {
    // For now just toggle between few or show simple sheet
    setState(
      () => _category = _category == 'Unlabelled' ? 'Work' : 'Unlabelled',
    );
  }

  void _showRepeatPicker() {
    setState(() => _repeatType = _repeatType == 'None' ? 'Daily' : 'None');
  }

  Widget _buildProgressTracking() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                Icon(
                  CupertinoIcons.graph_circle,
                  color: isDark ? Colors.white70 : Colors.black87,
                ),
                const SizedBox(width: 16),
                Text(
                  'Track Progress',
                  style: GoogleFonts.outfit(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ],
            ),
            CupertinoSwitch(
              value: _isProgressTracked,
              activeColor: AppTheme.primaryColor,
              onChanged: (val) => setState(() => _isProgressTracked = val),
            ),
          ],
        ),
        if (_isProgressTracked) ...[
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Divide the task into -',
                style: GoogleFonts.outfit(
                  color: isDark ? Colors.white38 : Colors.black38,
                  fontSize: 14,
                ),
              ),
              GestureDetector(
                onTap: () => setState(
                  () => _progressType = _progressType == 'Percentage'
                      ? 'Subtasks'
                      : 'Percentage',
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: isDark
                        ? Colors.white.withOpacity(0.05)
                        : Colors.black.withOpacity(0.05),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    _progressType,
                    style: GoogleFonts.outfit(
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _buildNoteInput() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(
          CupertinoIcons.text_alignleft,
          color: isDark ? Colors.white24 : Colors.black26,
          size: 24,
        ),
        const SizedBox(width: 16),
        Expanded(
          child: TextField(
            controller: _noteController,
            maxLines: null,
            style: GoogleFonts.outfit(
              color: isDark ? Colors.white70 : Colors.black87,
              fontSize: 16,
            ),
            decoration: InputDecoration(
              hintText: 'Add note/comments...',
              hintStyle: GoogleFonts.outfit(
                color: isDark ? Colors.white12 : Colors.black12,
              ),
              border: InputBorder.none,
              isDense: true,
            ),
          ),
        ),
      ],
    );
  }
}
