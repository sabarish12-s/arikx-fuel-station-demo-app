import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_demo_app/utils/user_facing_errors.dart';

void main() {
  group('userFacingErrorMessage', () {
    test('hides ClientSoftware connection abort details', () {
      expect(
        userFacingErrorMessage(
          'ClientSoftware caused connection abort, '
          'uri=https://rkfuelsapi.vercel.app/auth/google',
        ),
        'Please try again.',
      );
    });

    test('hides ClientException details with urls', () {
      expect(
        userFacingErrorMessage(
          'Exception: ClientException: Connection closed before full header '
          'was received, uri=https://rkfuelsapi.vercel.app/auth/google',
        ),
        'Please try again.',
      );
    });

    test('hides Firestore and backend permission internals', () {
      expect(
        userFacingErrorMessage(
          'Cloud Firestore API has not been used in project before or it is '
          'disabled. PERMISSION_DENIED',
        ),
        'Please try again.',
      );
    });

    test('hides html response dumps', () {
      expect(
        userFacingErrorMessage('<!DOCTYPE html><html><body>Cannot POST</body>'),
        'Please try again.',
      );
    });

    test('hides empty and unknown errors', () {
      expect(userFacingErrorMessage(null), 'Please try again.');
      expect(userFacingErrorMessage(''), 'Please try again.');
      expect(userFacingErrorMessage('Unknown error'), 'Please try again.');
    });

    test('keeps readable business messages', () {
      expect(
        userFacingErrorMessage('Exception: Approved entries cannot be edited.'),
        'Approved entries cannot be edited.',
      );
      expect(
        userFacingErrorMessage('Credit customer name is required.'),
        'Credit customer name is required.',
      );
    });

    test('keeps user cancelled sign-in message', () {
      expect(
        userFacingErrorMessage('Exception: Google Sign-In was cancelled.'),
        'Google Sign-In was cancelled.',
      );
    });
  });
}
