import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../theme/app_theme.dart';

class AnimatedBackground extends StatelessWidget {
  final Widget child;

  const AnimatedBackground({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Stack(
      children: [
        // Base Background Color
        Container(
          color: isDark ? AppTheme.statsDarkBackground : AppTheme.background,
        ),

        // Animated Blobs
        // We use slightly more transparent blobs for light mode so they aren't overwhelming
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
                          AppTheme.primaryColor.withOpacity(isDark ? 0.4 : 0.2),
                          AppTheme.primaryColor.withOpacity(0),
                        ],
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .move(
                    begin: const Offset(0, 0),
                    end: const Offset(-50, 40),
                    duration: 5.seconds,
                    curve: Curves.easeInOut,
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.2, 1.2),
                    duration: 6.seconds,
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
                          AppTheme.secondaryColor.withOpacity(
                            isDark ? 0.3 : 0.15,
                          ),
                          AppTheme.secondaryColor.withOpacity(0),
                        ],
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .move(
                    begin: const Offset(0, 0),
                    end: const Offset(40, -50),
                    duration: 6.seconds,
                    curve: Curves.easeInOut,
                  )
                  .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 7.seconds,
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
                          AppTheme.primaryColor.withOpacity(isDark ? 0.2 : 0.1),
                          AppTheme.primaryColor.withOpacity(0),
                        ],
                      ),
                    ),
                  )
                  .animate(onPlay: (c) => c.repeat(reverse: true))
                  .move(
                    begin: const Offset(0, 0),
                    end: const Offset(30, 30),
                    duration: 8.seconds,
                    curve: Curves.easeInOut,
                  ),
        ),

        // Child Content
        child,
      ],
    );
  }
}
