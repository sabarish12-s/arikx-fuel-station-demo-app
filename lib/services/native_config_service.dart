import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

class NativeConfigService {
  static const MethodChannel _channel = MethodChannel(
    'com.rk.fuels.rk_fuels/native_config',
  );

  static Future<String?> defaultWebClientId() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final String? value = await _channel.invokeMethod<String>(
      'getDefaultWebClientId',
    );
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }

  static Future<String?> pickGoogleAccountEmail() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) {
      return null;
    }

    final String? value = await _channel.invokeMethod<String>(
      'pickGoogleAccount',
    );
    if (value == null || value.trim().isEmpty) {
      return null;
    }
    return value.trim();
  }
}
