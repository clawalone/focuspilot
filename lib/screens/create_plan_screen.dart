import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../theme/app_theme.dart';
import 'app_limiter_screen.dart';
import '../services/settings_service.dart';
import '../services/app_service.dart';

class CreatePlanScreen extends StatefulWidget {
  final String? initialCategory;

  const CreatePlanScreen({super.key, this.initialCategory});

  @override
  State<CreatePlanScreen> createState() => _CreatePlanScreenState();
}

class _CreatePlanScreenState extends State<CreatePlanScreen> {
  int _selectedMinutes = 25;
  late FixedExtentScrollController _scrollController;
  late TextEditingController _textController;
  bool _isInit = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_isInit) {
      final settings = Provider.of<SettingsService>(context, listen: false);
      // Prefetch apps
      Provider.of<AppService>(context, listen: false).loadApps();

      _selectedMinutes = settings.getFocusDuration();
      _scrollController = FixedExtentScrollController(
        initialItem: _selectedMinutes - 1,
      );
      _isInit = false;
    }
  }

  @override
  void initState() {
    super.initState();
    _textController = TextEditingController(text: widget.initialCategory);
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Custom Back Button
              Padding(
                padding: const EdgeInsets.only(bottom: 16.0),
                child: IconButton(
                  alignment: Alignment.centerLeft,
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.arrow_back_ios,
                    size: 20,
                    color: isDark ? Colors.white : Colors.black,
                  ),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              Text(
                'create a new plan',
                style: Theme.of(context).textTheme.displayMedium,
              ),
              const SizedBox(height: 8),
              Text(
                'what do you want to focus on?',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 32),

              // Input Field
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 20,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: isDark ? Colors.grey.shade900 : Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: TextField(
                  controller: _textController,
                  decoration: InputDecoration(
                    border: InputBorder.none,
                    hintText: 'study',
                    hintStyle: TextStyle(color: Colors.grey.shade500),
                  ),
                  style: TextStyle(
                    color: isDark ? Colors.white : Colors.black,
                    fontSize: 16,
                  ),
                ),
              ),
              const SizedBox(height: 48),

              // Time Selection Display
              Center(
                child: Text(
                  '$_selectedMinutes',
                  style: Theme.of(
                    context,
                  ).textTheme.displayLarge?.copyWith(fontSize: 80),
                ),
              ),
              const SizedBox(height: 20),

              // Custom Horizontal Time Picker
              SizedBox(
                height: 100,
                child: RotatedBox(
                  quarterTurns: -1,
                  child: ListWheelScrollView(
                    controller: _scrollController,
                    itemExtent: 60,
                    perspective: 0.005,
                    diameterRatio: 1.2,
                    physics: const FixedExtentScrollPhysics(),
                    onSelectedItemChanged: (index) {
                      setState(() {
                        _selectedMinutes = index + 1;
                      });
                    },
                    children: List.generate(120, (index) {
                      final value = index + 1;
                      final isSelected = value == _selectedMinutes;
                      return RotatedBox(
                        quarterTurns: 1,
                        child: Center(
                          child: AnimatedDefaultTextStyle(
                            duration: const Duration(milliseconds: 200),
                            style: TextStyle(
                              fontSize: isSelected ? 32 : 20,
                              color: isSelected
                                  ? AppTheme.primaryColor
                                  : Colors.grey.shade300,
                              fontWeight: isSelected
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                            child: Text('$value'),
                          ),
                        ),
                      );
                    }),
                  ),
                ),
              ),

              // Triangle Indicator
              Center(
                child: CustomPaint(
                  size: const Size(20, 10),
                  painter: TrianglePainter(),
                ),
              ),

              const Spacer(),

              // Continue Button
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
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => AppLimiterScreen(
                          category: _textController.text.isEmpty
                              ? 'Focus'
                              : _textController.text,
                          durationInMinutes: _selectedMinutes,
                        ),
                      ),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.transparent,
                    shadowColor: Colors.transparent,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(28),
                    ),
                  ),
                  child: const Text(
                    'continue',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class TrianglePainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppTheme.primaryColor
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(0, size.height);
    path.lineTo(size.width / 2, 0);
    path.lineTo(size.width, size.height);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
