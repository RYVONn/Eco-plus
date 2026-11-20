import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/driver/driver_app.dart';
import 'package:ecoplus_app/roles/driver/driver_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('driver checks the van, starts the shift and rejects a wrong code', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const DriverApp()),
    ));
    await tester.pumpAndSettle();

    for (final label in ['الفرامل والكاوتش تمام', 'البنزين كفاية', 'أكياس وقفازات متوفرة', 'الموبايل والشاحن']) {
      await tester.tap(find.text(label));
      await tester.pump();
    }
    await tester.tap(find.text('ابدأ الوردية'));
    await tester.pumpAndSettle();
    expect(container.read(driverProvider).started, isTrue);

    await tester.tap(find.text('كافيه المثال'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('وصلت · اطلب الكود'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField), '1111');
    await tester.pump();
    await tester.tap(find.text('تأكيد الكود'));
    await tester.pumpAndSettle();
    expect(find.text('الكود غلط. اطلب من العميل يراجعه.'), findsOneWidget);
  });
}
