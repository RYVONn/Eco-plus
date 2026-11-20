import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/citizen/citizen_app.dart';
import 'package:ecoplus_app/roles/citizen/citizen_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('citizen scans a bag and books a pickup', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(citizenOnboardedProvider.notifier).done();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const CitizenApp()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('صوّر كيس'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التقاط'));
    await tester.pump();
    await tester.pump(const Duration(seconds: 3));
    await tester.pumpAndSettle();
    expect(find.text('نتيجة التحليل'), findsOneWidget);

    await tester.tap(find.text('اختار الميعاد'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أكّد الاستلام'));
    await tester.pumpAndSettle();

    expect(find.text('اتحجز الاستلام'), findsOneWidget);
    expect(container.read(citizenProvider).ships.first.id, 'EP-1043');
  });
}
