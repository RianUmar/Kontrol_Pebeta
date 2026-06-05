// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_kontrol/services/control_mapping_service.dart';

import 'package:flutter_kontrol/main.dart';

void main() {
  testWidgets('Core App Load Smoke Test', (WidgetTester tester) async {
    // Mock SharedPreferences values for testing
    SharedPreferences.setMockInitialValues({});

    // Initialize ControlMappingService to prevent uninitialized lateness errors
    await ControlMappingService().init();

    // Build our app and trigger a frame, disabling tickers to prevent pending animation timers.
    await tester.pumpWidget(const TickerMode(
      enabled: false,
      child: HexapodControllerApp(),
    ));

    // Verify that the dashboard header is present
    expect(find.text('ROBOTECH TADULAKO'), findsAtLeastNWidgets(1));

    // Clean up the widget tree and allow all disposals to complete
    await tester.pumpWidget(const SizedBox());
    await tester.pumpAndSettle();
  });
}
