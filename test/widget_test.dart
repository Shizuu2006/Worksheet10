import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

import 'package:kosfinder_device_demo/main.dart';

void main() {
  testWidgets('KosFinder app renders the main page', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const KosFinderDeviceApp());
    await tester.pump();

    expect(find.text('KosFinder'), findsOneWidget);
    expect(find.text('Kamera'), findsOneWidget);
    expect(find.text('Galeri'), findsOneWidget);
    await tester.scrollUntilVisible(
      find.text('Ambil Koordinat GPS'),
      300,
      scrollable: find.byType(Scrollable).first,
    );
    expect(find.text('Ambil Koordinat GPS'), findsOneWidget);
  });

  testWidgets('Sensor page opens from the main app bar', (
    WidgetTester tester,
  ) async {
    SharedPreferencesAsyncPlatform.instance =
        InMemorySharedPreferencesAsync.empty();
    await tester.pumpWidget(const KosFinderDeviceApp());
    await tester.pump();

    await tester.tap(find.byTooltip('Demo sensor'));
    await tester.pumpAndSettle();

    expect(find.text('Demo Accelerometer'), findsOneWidget);
    expect(find.text('Sumbu X'), findsOneWidget);
    expect(find.text('Sumbu Y'), findsOneWidget);
    expect(find.text('Sumbu Z'), findsOneWidget);
  });
}
