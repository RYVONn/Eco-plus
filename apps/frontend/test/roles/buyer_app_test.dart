import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/buyer/buyer_app.dart';
import 'package:ecoplus_app/roles/buyer/buyer_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('buyer opens a lot and places an order', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 2000);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);
    container.read(buyerOnboardedProvider.notifier).done();

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const BuyerApp()),
    ));
    await tester.pumpAndSettle();

    await tester.tap(find.text('بلاستيك مخلوط'));
    await tester.pumpAndSettle();
    expect(find.text('تفاصيل الدفعة'), findsOneWidget);
    await tester.tap(find.text('اطلب'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('أكّد الطلب'));
    await tester.pumpAndSettle();

    expect(find.text('الطلب اتسجّل'), findsOneWidget);
    expect(container.read(buyerProvider).orders.first.id, 2032);
  });
}
