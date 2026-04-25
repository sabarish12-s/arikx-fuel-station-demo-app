import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:fuel_station_demo_app/screens/login_screen.dart';

void main() {
  testWidgets('Login screen renders key content', (WidgetTester tester) async {
    await tester.pumpWidget(const MaterialApp(home: LoginScreen()));

    expect(find.text('Arikx fuel station'), findsOneWidget);
    expect(find.text('Continue to your station workspace'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}
