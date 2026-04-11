import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:rk_fuels/utils/formatters.dart';
import 'package:rk_fuels/widgets/app_bottom_nav_bar.dart';
import 'package:rk_fuels/widgets/responsive_text.dart';

void main() {
  const phoneWidths = <double>[320, 360, 390, 430, 480];

  testWidgets('OneLineScaleText keeps compact values on one line', (
    tester,
  ) async {
    const values = <String>[
      '0.00 L',
      '478 (middle)',
      'Var Rs 0.64',
      'Rs 1,23,456.00',
      'Dashboard',
      'Inventory',
    ];

    for (final width in phoneWidths) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(1.35),
            ),
            child: Scaffold(
              body: Column(
                children: [
                  for (final value in values)
                    SizedBox(width: width / 3, child: OneLineScaleText(value)),
                ],
              ),
            ),
          ),
        ),
      );

      expect(tester.takeException(), isNull);
    }
  });

  testWidgets('bottom nav labels stay stable on common phone widths', (
    tester,
  ) async {
    for (final width in phoneWidths) {
      await tester.pumpWidget(
        MaterialApp(
          home: MediaQuery(
            data: MediaQueryData(
              size: Size(width, 800),
              textScaler: const TextScaler.linear(1.25),
            ),
            child: Scaffold(
              bottomNavigationBar: AppBottomNavBar(
                selectedIndex: 0,
                onSelected: (_) {},
                items: const [
                  AppBottomNavItem(
                    icon: Icons.grid_view_rounded,
                    label: 'Dashboard',
                  ),
                  AppBottomNavItem(
                    icon: Icons.edit_note_rounded,
                    label: 'Entries',
                  ),
                  AppBottomNavItem(
                    icon: Icons.bar_chart_rounded,
                    label: 'Reports',
                  ),
                  AppBottomNavItem(
                    icon: Icons.local_gas_station_outlined,
                    label: 'Inventory',
                  ),
                  AppBottomNavItem(
                    icon: Icons.manage_accounts_outlined,
                    label: 'Settings',
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Dashboard'), findsOneWidget);
      expect(find.text('Inventory'), findsOneWidget);
      expect(tester.takeException(), isNull);
    }
  });

  test('metric formatters keep value and unit together', () {
    expect(formatLiters(0), '0.00\u00A0L');
    expect(formatCurrency(123456), 'Rs\u00A01,23,456.00');
  });
}
