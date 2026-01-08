import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'app_limiter_screen.dart';
import '../services/settings_service.dart';
import '../services/app_service.dart';
import '../theme/app_theme.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';

class CreatePlanScreen extends StatefulWidget {
  final String? initialCategory;

  const CreatePlanScreen({super.key, this.initialCategory});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  int _workMinutes = 1;
  int _reviseMinutes = 10;
  int _breakMinutes = 5;
  int _sessionsCount = 3;
  bool _isReviseBefore = false;
  bool _enableRevision = true;
  bool _showInfoBox = true;
  String _category = 'Unlabelled';
  final TextEditingController _noteController = TextEditingController();
  final ScrollController _workScrollController = ScrollController();
  final ScrollController _reviseScrollController = ScrollController();
  final ScrollController _breakScrollController = ScrollController();
  final ScrollController _sessionsScrollController = ScrollController();

  final List<int> _workOptions = List.generate(120, (i) => i + 1);
  final List<int> _reviseOptions = List.generate(30, (i) => i + 1);
  final List<int> _breakOptions = List.generate(60, (i) => i + 1);
  final List<int> _sessionsOptions = List.generate(10, (i) => i + 1);

  @override
  void initState() {
    super.initState();
    if (widget.initialCategory != null && widget.initialCategory!.isNotEmpty) {
      _category = widget.initialCategory!;
    }
    // Load defaults from settings
    final settings = Provider.of<SettingsService>(context, listen: false);
    _workMinutes = settings.getFocusDuration();

    // Prefetch apps and scroll to selections
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<AppService>(context, listen: false).loadApps();
      _scrollToInitialValues();
    });
  }

  void _scrollToInitialValues() {
    // Approximate width: text (~20-30px) + padding (24px)
    // We'll use a conservative estimate to bring it into view
    void scroll(ScrollController controller, int value, List<int> options) {
      if (!controller.hasClients) return;
      final index = options.indexOf(value);
      if (index != -1) {
        // Precise offset: 60px per item (fixed width container)
        controller.animateTo(
          index * 60.0,
          duration: const Duration(milliseconds: 500),
          curve: Curves.easeOut,
        );
      }
    }

    scroll(_workScrollController, _workMinutes, _workOptions);
    scroll(_reviseScrollController, _reviseMinutes, _reviseOptions);
    scroll(_breakScrollController, _breakMinutes, _breakOptions);
    scroll(_sessionsScrollController, _sessionsCount, _sessionsOptions);
  }

  @override
  void dispose() {
    _noteController.dispose();
    _workScrollController.dispose();
    _reviseScrollController.dispose();
    _breakScrollController.dispose();
    _sessionsScrollController.dispose();
    super.dispose();
  }

  DateTime _calculateFinishTime() {
    int totalMinutes = 0;
    if (_enableRevision) {
      totalMinutes += _reviseMinutes; // Revision phase
    }
    totalMinutes += (_workMinutes * _sessionsCount); // Work phases
    totalMinutes +=
        (_breakMinutes *
        (_sessionsCount - 1)); // Break phases (one less than sessions)

    return DateTime.now().add(Duration(minutes: totalMinutes));
  }

  @override
  Widget build(BuildContext context) {
    final finishTime = _calculateFinishTime();
    final finishTimeString = DateFormat(
      'h:mm a',
    ).format(finishTime).toLowerCase();

    return Scaffold(
      backgroundColor: AppTheme.statsDarkBackground,
      body: Stack(
        children: [
          // Base Background
          Container(color: AppTheme.statsDarkBackground),

          // Background Blobs (Mesh Gradient)
          Positioned(
            top: -100,
            right: -100,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.4),
                            AppTheme.primaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .move(
                      begin: const Offset(0, 0),
                      end: const Offset(-50, 40),
                      duration: 10.seconds,
                      curve: Curves.easeInOut,
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.2, 1.2),
                      duration: 12.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            bottom: -100,
            left: -100,
            child:
                Container(
                      width: 400,
                      height: 400,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.secondaryColor.withOpacity(0.3),
                            AppTheme.secondaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .move(
                      begin: const Offset(0, 0),
                      end: const Offset(40, -50),
                      duration: 12.seconds,
                      curve: Curves.easeInOut,
                    )
                    .scale(
                      begin: const Offset(1, 1),
                      end: const Offset(1.1, 1.1),
                      duration: 14.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),
          Positioned(
            top: 200,
            left: -150,
            child:
                Container(
                      width: 350,
                      height: 350,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(
                          colors: [
                            AppTheme.primaryColor.withOpacity(0.2),
                            AppTheme.primaryColor.withOpacity(0),
                          ],
                        ),
                      ),
                    )
                    .animate(onPlay: (c) => c.repeat(reverse: true))
                    .move(
                      begin: const Offset(0, 0),
                      end: const Offset(30, 30),
                      duration: 15.seconds,
                      curve: Curves.easeInOut,
                    ),
          ),

          // Main Content
          SafeArea(
            child: Column(
              children: [
                AppBar(
                  backgroundColor: Colors.transparent,
                  elevation: 0,
                  centerTitle: true,
                  leading: IconButton(
                    icon: const Icon(
                      Icons.pentagon_outlined,
                      color: Colors.white70,
                      size: 24,
                    ),
                    onPressed: () => Navigator.pop(context),
                  ),
                  title: Text(
                    _category.toLowerCase(),
                    style: GoogleFonts.outfit(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  actions: const [],
                ),
                Expanded(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 24.0),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const SizedBox(height: 20),
                          if (_showInfoBox)
                            Container(
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: AppTheme.statsCardBackground,
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: Colors.white.withOpacity(0.05),
                                ),
                              ),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Expanded(
                                    child: Text(
                                      'Revision at the start or end of a work/study session helps to retain things better and makes your work time more efficient and organised.',
                                      style: TextStyle(
                                        color: Colors.white70,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                  TextButton(
                                    onPressed: () =>
                                        setState(() => _showInfoBox = false),
                                    child: Text(
                                      'Got it',
                                      style: GoogleFonts.outfit(
                                        color: AppTheme.primaryColor,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          const SizedBox(height: 32),

                          // Durations Group
                          ...(_isReviseBefore
                              ? [
                                  if (_enableRevision) ...[
                                    _buildSelectionRow(
                                      label: 'Revise',
                                      currentValue: _reviseMinutes,
                                      options: _reviseOptions,
                                      onChanged: (val) =>
                                          setState(() => _reviseMinutes = val),
                                      controller: _reviseScrollController,
                                    ),
                                    const SizedBox(height: 24),
                                  ],
                                  _buildSelectionRow(
                                    label: 'Work',
                                    currentValue: _workMinutes,
                                    options: _workOptions,
                                    onChanged: (val) =>
                                        setState(() => _workMinutes = val),
                                    controller: _workScrollController,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildSelectionRow(
                                    label: 'Break',
                                    currentValue: _breakMinutes,
                                    options: _breakOptions,
                                    onChanged: (val) =>
                                        setState(() => _breakMinutes = val),
                                    controller: _breakScrollController,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildSelectionRow(
                                    label: 'Sessions',
                                    currentValue: _sessionsCount,
                                    options: _sessionsOptions,
                                    onChanged: (val) =>
                                        setState(() => _sessionsCount = val),
                                    unit: '',
                                    controller: _sessionsScrollController,
                                  ),
                                ]
                              : [
                                  _buildSelectionRow(
                                    label: 'Work',
                                    currentValue: _workMinutes,
                                    options: _workOptions,
                                    onChanged: (val) =>
                                        setState(() => _workMinutes = val),
                                    controller: _workScrollController,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildSelectionRow(
                                    label: 'Break',
                                    currentValue: _breakMinutes,
                                    options: _breakOptions,
                                    onChanged: (val) =>
                                        setState(() => _breakMinutes = val),
                                    controller: _breakScrollController,
                                  ),
                                  const SizedBox(height: 24),
                                  _buildSelectionRow(
                                    label: 'Sessions',
                                    currentValue: _sessionsCount,
                                    options: _sessionsOptions,
                                    onChanged: (val) =>
                                        setState(() => _sessionsCount = val),
                                    unit: '',
                                    controller: _sessionsScrollController,
                                  ),
                                  const SizedBox(height: 24),
                                  if (_enableRevision) ...[
                                    _buildSelectionRow(
                                      label: 'Revise',
                                      currentValue: _reviseMinutes,
                                      options: _reviseOptions,
                                      onChanged: (val) =>
                                          setState(() => _reviseMinutes = val),
                                      controller: _reviseScrollController,
                                    ),
                                  ],
                                ]),
                          const SizedBox(height: 32),

                          Row(
                            children: [
                              Expanded(
                                child: _buildToggleButton(
                                  label: 'Revise Before',
                                  isSelected:
                                      _enableRevision && _isReviseBefore,
                                  onTap: () => setState(() {
                                    if (_enableRevision && _isReviseBefore) {
                                      _enableRevision = false;
                                    } else {
                                      _enableRevision = true;
                                      _isReviseBefore = true;
                                    }
                                  }),
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: _buildToggleButton(
                                  label: 'Revise After',
                                  isSelected:
                                      _enableRevision && !_isReviseBefore,
                                  onTap: () => setState(() {
                                    if (_enableRevision && !_isReviseBefore) {
                                      _enableRevision = false;
                                    } else {
                                      _enableRevision = true;
                                      _isReviseBefore = false;
                                    }
                                  }),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 32),

                          _buildIconRow(
                            icon: Icons.label_important_outline,
                            label: _category,
                            onTap: () => _showCategoryPicker(context),
                          ),
                          const Divider(color: Colors.white10),

                          _buildIconRow(
                            icon: Icons.notes,
                            label: _noteController.text.isEmpty
                                ? 'Comment/Note'
                                : _noteController.text,
                            onTap: () => _showNoteDialog(),
                          ),
                          const SizedBox(height: 48),

                          Container(
                            width: double.infinity,
                            height: 56,
                            decoration: BoxDecoration(
                              gradient: AppTheme.primaryGradient,
                              borderRadius: BorderRadius.circular(28),
                              boxShadow: [
                                BoxShadow(
                                  color: AppTheme.primaryColor.withOpacity(0.3),
                                  blurRadius: 12,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: ElevatedButton(
                              onPressed: _startSession,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: Colors.transparent,
                                shadowColor: Colors.transparent,
                                foregroundColor: Colors.white,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(28),
                                ),
                              ),
                              child: Text(
                                'Start Focus Session',
                                style: GoogleFonts.outfit(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          Center(
                            child: Text(
                              'Estimated to finish at $finishTimeString',
                              style: GoogleFonts.outfit(
                                color: Colors.white38,
                                fontSize: 14,
                              ),
                            ),
                          ),
                          const SizedBox(height: 40),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSelectionRow({
    required String label,
    required int currentValue,
    required List<int> options,
    required ValueChanged<int> onChanged,
    required ScrollController controller,
    String unit = 'Minutes',
  }) {
    return Row(
      children: [
        SizedBox(
          width: 80,
          child: Text(
            label,
            style: GoogleFonts.outfit(color: Colors.white70, fontSize: 18),
          ),
        ),
        Expanded(
          child: SingleChildScrollView(
            controller: controller,
            scrollDirection: Axis.horizontal,
            child: Row(
              children: options.map((val) {
                final isSelected = val == currentValue;
                return GestureDetector(
                  onTap: () => onChanged(val),
                  child: SizedBox(
                    width: 60,
                    child: Center(
                      child: Text(
                        '$val',
                        style: GoogleFonts.outfit(
                          color: isSelected ? Colors.white : Colors.white24,
                          fontSize: isSelected ? 32 : 20,
                          fontWeight: isSelected
                              ? FontWeight.bold
                              : FontWeight.normal,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ),
        if (unit.isNotEmpty)
          Text(
            unit,
            style: GoogleFonts.outfit(color: Colors.white38, fontSize: 14),
          ),
      ],
    );
  }

  Widget _buildToggleButton({
    required String label,
    required bool isSelected,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 48,
        decoration: BoxDecoration(
          color: isSelected ? AppTheme.primaryColor : Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: isSelected ? AppTheme.primaryColor : Colors.white10,
          ),
        ),
        child: Center(
          child: Text(
            label,
            style: GoogleFonts.outfit(
              color: isSelected ? Colors.white : Colors.white38,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIconRow({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      behavior: HitTestBehavior.opaque,
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 16.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white38),
            const SizedBox(width: 16),
            Text(
              label,
              style: GoogleFonts.outfit(color: Colors.white70, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  void _showNoteDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppTheme.statsCardBackground,
        title: Text('Add Note', style: GoogleFonts.outfit(color: Colors.white)),
        content: TextField(
          controller: _noteController,
          style: GoogleFonts.outfit(color: Colors.white),
          decoration: InputDecoration(
            hintText: 'Enter your note here...',
            hintStyle: GoogleFonts.outfit(color: Colors.white24),
            border: UnderlineInputBorder(
              borderSide: BorderSide(color: AppTheme.primaryColor),
            ),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              'Cancel',
              style: GoogleFonts.outfit(color: Colors.white38),
            ),
          ),
          TextButton(
            onPressed: () {
              setState(() {});
              Navigator.pop(context);
            },
            child: Text(
              'Save',
              style: GoogleFonts.outfit(
                color: AppTheme.primaryColor,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showCategoryPicker(BuildContext context) {
    final categories = ['Unlabelled', 'Work', 'Study', 'Personal', 'Other'];
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.statsCardBackground,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return Container(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'Select Category',
                style: GoogleFonts.outfit(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 16),
              ...categories.map(
                (cat) => ListTile(
                  title: Text(
                    cat,
                    style: GoogleFonts.outfit(color: Colors.white70),
                  ),
                  onTap: () {
                    setState(() => _category = cat);
                    Navigator.pop(context);
                  },
                ),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _startSession() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (context) => AppLimiterScreen(
          category: _category,
          workMinutes: _workMinutes,
          reviseMinutes: _enableRevision ? _reviseMinutes : 0,
          breakMinutes: _breakMinutes,
          sessionsCount: _sessionsCount,
          isReviseBefore: _isReviseBefore,
          note: _noteController.text,
        ),
      ),
    );
  }
}
