import 'package:flutter/services.dart';
import 'dart:io';

class PermissionService {
  static const MethodChannel _channel = MethodChannel(
    'com.example.focusflow/permissions',
  );

  Future<bool> checkUsagePermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool granted = await _channel.invokeMethod('checkUsagePermission');
      return granted;
    } on PlatformException catch (e) {
      print("Failed to check usage permission: '${e.message}'.");
      return false;
    }
  }

  Future<void> requestUsagePermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestUsagePermission');
    } on PlatformException catch (e) {
      print("Failed to request usage permission: '${e.message}'.");
    }
  }

  Future<bool> checkOverlayPermission() async {
    if (!Platform.isAndroid) return true;
    try {
      final bool granted = await _channel.invokeMethod(
        'checkOverlayPermission',
      );
      return granted;
    } on PlatformException catch (e) {
      print("Failed to check overlay permission: '${e.message}'.");
      return false;
    }
  }

  Future<void> requestOverlayPermission() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('requestOverlayPermission');
    } on PlatformException catch (e) {
      print("Failed to request overlay permission: '${e.message}'.");
    }
  }

  Future<String?> getForegroundApp() async {
    if (!Platform.isAndroid) return null;
    try {
      final String? packageName = await _channel.invokeMethod(
        'getForegroundApp',
      );
      return packageName;
    } on PlatformException catch (e) {
      print("Failed to get foreground app: '${e.message}'.");
      return null;
    }
  }

  Future<void> bringAppToFront() async {
    if (!Platform.isAndroid) return;
    try {
      await _channel.invokeMethod('bringAppToFront');
    } on PlatformException catch (e) {
      print("Failed to bring app to front: '${e.message}'.");
    }
  }
}
