const String defaultUserFacingErrorMessage = 'Please try again.';

String userFacingErrorMessage(
  Object? error, {
  String fallback = defaultUserFacingErrorMessage,
}) {
  final String safeFallback =
      fallback.trim().isEmpty ? defaultUserFacingErrorMessage : fallback.trim();
  final String raw = error?.toString().trim() ?? '';
  if (raw.isEmpty) {
    return safeFallback;
  }

  final String message = _stripDartPrefixes(raw).trim();
  if (message.isEmpty || _looksTechnical(raw) || _looksTechnical(message)) {
    return safeFallback;
  }

  return message;
}

String _stripDartPrefixes(String value) {
  var message = value.trim();
  const List<String> prefixes = <String>['Exception: ', 'Error: '];

  var changed = true;
  while (changed) {
    changed = false;
    for (final String prefix in prefixes) {
      if (message.startsWith(prefix)) {
        message = message.substring(prefix.length).trim();
        changed = true;
      }
    }
  }
  return message;
}

bool _looksTechnical(String value) {
  final String message = value.trim();
  final String lower = message.toLowerCase();
  if (lower.isEmpty) {
    return true;
  }

  if (lower.startsWith('<!doctype html') || lower.startsWith('<html')) {
    return true;
  }

  if (RegExp(r'(^|\r?\n)#\d+\s').hasMatch(message) ||
      RegExp(r'\b[\w_]+\.dart:\d+').hasMatch(message)) {
    return true;
  }

  const List<String> technicalFragments = <String>[
    'argumenterror',
    'assertionerror',
    'certificate_verify_failed',
    'clientexception',
    'clientsoftware',
    'cloud firestore api has not been used',
    'connection abort',
    'connection refused',
    'connection reset',
    'errno',
    'failed host lookup',
    'firebase storage/auth access',
    'firebaseexception',
    'formatexception',
    'handshakeexception',
    'httpexception',
    'http://',
    'https://',
    'internal server error',
    'invalid response',
    'missingpluginexception',
    'network error',
    'network is unreachable',
    'no such method',
    'null check operator',
    'os error',
    'package:flutter',
    'package:http',
    'permission_denied',
    'platformexception',
    'rangeerror',
    'request failed with status',
    'server returned',
    'socketexception',
    'stack trace',
    'stacktrace',
    'stateerror',
    'timeoutexception',
    'typeerror',
    'unknown error',
    'unknown exception',
    'uri=',
    'xmlhttprequest error',
  ];

  return technicalFragments.any(lower.contains);
}
