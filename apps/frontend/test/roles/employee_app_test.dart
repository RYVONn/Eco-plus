import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/employee/employee_app.dart';
import 'package:ecoplus_app/roles/employee/employee_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('employee receives, weighs and saves a shipment', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1600);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const EmployeeApp()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('كافيه المثال'), findsOneWidget);

    await tester.tap(find.text('كافيه المثال'));
    await tester.pumpAndSettle();
    expect(find.text('استلمت وابدأ الوزن'), findsOneWidget);

    await tester.tap(find.text('صوّر الأكياس المستلمة'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('استلمت وابدأ الوزن'));
    await tester.pumpAndSettle();

    await tester.tap(find.text('صوّر الميزان بالوزن'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('احفظ الوزن'));
    await tester.pumpAndSettle();

    expect(find.text('اتسجّل الوزن'), findsOneWidget);
    expect(container.read(employeeProvider).count(ShipStatus.weighed), 1);
  });
}
