import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:google_fonts/google_fonts.dart';
import '../screens/calendar_screen.dart';

class HomeHeader extends StatefulWidget {
  final GlobalKey? dateKey;

  const HomeHeader({super.key, this.dateKey});

  @override
  State<HomeHeader> createState() => _HomeHeaderState();
}

class _HomeHeaderState extends State<HomeHeader> {
  @override
  void initState() {
    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final dateStr = DateFormat('EEEE, d MMM').format(DateTime.now());

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'FocusPilot',
              style: GoogleFonts.grandHotel(
                textStyle: theme.textTheme.displaySmall?.copyWith(
                  color: isDark ? Colors.white : Colors.black87,
                  fontSize: 36,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            Row(
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const CalendarScreen(),
                      ),
                    );
                  },
                  child: Container(
                    key: widget.dateKey,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: theme.colorScheme.surface,
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: isDark ? Colors.white10 : Colors.grey.shade200,
                      ),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.calendar_month,
                          size: 18,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          dateStr,
                          style: theme.textTheme.labelMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
