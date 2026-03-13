import 'package:flutter/services.dart';

/// Platform channel helper for direct SMS, calls, and accessibility service management.
class NativeCommChannel {
  static const _channel = MethodChannel('com.example.safeher/native_comm');

  /// Sends an SMS directly without opening the SMS app.
  static Future<bool> sendSms({
    required String phoneNumber,
    required String message,
  }) async {
    try {
      final result = await _channel.invokeMethod('sendSms', {
        'phoneNumber': phoneNumber,
        'message': message,
      });
      return result == true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Places a phone call directly without opening the dialer.
  static Future<bool> makeDirectCall({
    required String phoneNumber,
  }) async {
    try {
      final result = await _channel.invokeMethod('makeDirectCall', {
        'phoneNumber': phoneNumber,
      });
      return result == true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Checks if the VolumeAccessibilityService is enabled.
  static Future<bool> isAccessibilityEnabled() async {
    try {
      final result = await _channel.invokeMethod('isAccessibilityEnabled');
      return result == true;
    } on PlatformException catch (_) {
      return false;
    }
  }

  /// Opens Android's Accessibility Settings so the user can enable the service.
  static Future<void> openAccessibilitySettings() async {
    try {
      await _channel.invokeMethod('openAccessibilitySettings');
    } on PlatformException catch (_) {
      // ignore
    }
  }
}
