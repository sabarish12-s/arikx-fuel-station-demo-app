import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_fuels/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders key content', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Fuel Station\nManager'), findsOneWidget);
    expect(find.text('Continue with\nGoogle'), findsOneWidget);
  });
}
