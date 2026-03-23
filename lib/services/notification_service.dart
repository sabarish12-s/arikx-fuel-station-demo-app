import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

class NotificationService {
  NotificationService._();
  static final NotificationService instance = NotificationService._();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;

  Future<void> initialize() async {
    if (kIsWeb) {
      return;
    }
    await _messaging.requestPermission();
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
