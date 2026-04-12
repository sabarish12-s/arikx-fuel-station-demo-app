import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();
  static const MethodChannel _channel = MethodChannel(
    'com.rk.fuels.rk_fuels/notifications',
  );

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }
    await _messaging.requestPermission();
    if (defaultTargetPlatform == TargetPlatform.android) {
      try {
        await _channel.invokeMethod<bool>('requestNotificationPermission');
      } catch (_) {
        // Ignore and continue without local download notifications.
      }
    }
  }

  Future<String?> getFcmToken() async {
    if (kIsWeb) {
      return null;
    }
    try {
      return await _messaging.getToken();
    } catch (_) {
      return null;
    }
  }
}
