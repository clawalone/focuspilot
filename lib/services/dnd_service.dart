import 'package:flutter_dnd/flutter_dnd.dart';

class DndService {
  Future<void> setInterruptionFilter(int filter) async {
    final isNotificationPolicyAccessGranted =
        await FlutterDnd.isNotificationPolicyAccessGranted;
    if (isNotificationPolicyAccessGranted == true) {
      await FlutterDnd.setInterruptionFilter(filter);
    }
  }

  Future<void> requestPermission() async {
    final isGranted = await isPermissionGranted();
    if (!isGranted) {
      FlutterDnd.gotoPolicySettings();
    }
  }

  Future<bool> isPermissionGranted() async {
    return await FlutterDnd.isNotificationPolicyAccessGranted ?? false;
  }

  Future<void> turnOnDnd() async {
    if (await isPermissionGranted()) {
      await FlutterDnd.setInterruptionFilter(
        FlutterDnd.INTERRUPTION_FILTER_NONE,
      );
    }
  }

  Future<void> turnOffDnd() async {
    if (await isPermissionGranted()) {
      await FlutterDnd.setInterruptionFilter(
        FlutterDnd.INTERRUPTION_FILTER_ALL,
      );
    }
  }
}
