import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/admin/admin_app.dart';
import 'package:ecoplus_app/roles/admin/admin_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('admin opens an account in support mode and leaves it', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(1400, 1000);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const AdminApp()),
    ));
    await tester.pumpAndSettle();
    expect(find.text('نظرة عامة'), findsWidgets);

    container.read(adminProvider.notifier).openPage('accounts');
    await tester.pumpAndSettle();
    await tester.tap(find.text('سارة').first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('ادخل على حسابه (وضع الدعم)'));
    await tester.pumpAndSettle();

    expect(container.read(adminProvider).support?.role, 'citizen');
    expect(find.textContaining('وضع الدعم'), findsOneWidget);

    await tester.tap(find.text('خروج'));
    await tester.pumpAndSettle();
    expect(container.read(adminProvider).support, isNull);
  });
}
