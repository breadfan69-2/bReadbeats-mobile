import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:breadbeats_mobile/main.dart';

void main() {
  testWidgets('shows setup wizard on first launch', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{});

    await tester.pumpWidget(const BreadbeatsMobileApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    // Wizard step 1: security warning
    expect(find.text('Network Security Warning'), findsOneWidget);
    expect(find.text('Next'), findsOneWidget);
    expect(find.text('Step 1 of 3'), findsOneWidget);

    // Advance to step 2: connection
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Device Connection'), findsOneWidget);
    expect(find.text('Step 2 of 3'), findsOneWidget);

    // Advance to step 3: calibration
    await tester.tap(find.text('Next'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('Calibration'), findsOneWidget);
    expect(find.text('Finish'), findsOneWidget);
    expect(find.text('Step 3 of 3'), findsOneWidget);

    // Finish → home screen
    await tester.tap(find.text('Finish'));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump(const Duration(milliseconds: 500));

    expect(find.text('CONNECTION'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
  });

  testWidgets('skips wizard when setup already completed', (
    WidgetTester tester,
  ) async {
    SharedPreferences.setMockInitialValues(<String, Object>{
      'ui.setup_wizard_completed': true,
    });

    await tester.pumpWidget(const BreadbeatsMobileApp());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Network Security Warning'), findsNothing);
    expect(find.text('CONNECTION'), findsOneWidget);
    expect(find.byIcon(Icons.play_circle), findsOneWidget);
  });
}
