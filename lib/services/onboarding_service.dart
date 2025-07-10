import 'package:shared_preferences/shared_preferences.dart';

class OnboardingService {
  static const String _keyHasSeenOnboarding = 'has_seen_onboarding_v1';

  static Future<bool> shouldShowOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    // Return true if the key doesn't exist (first time)
    return !(prefs.getBool(_keyHasSeenOnboarding) ?? false);
  }

  static Future<void> markOnboardingComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_keyHasSeenOnboarding, true);
  }

  // Debug method to reset onboarding
  static Future<void> resetOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyHasSeenOnboarding);
  }
}
