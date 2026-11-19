import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/business/business_app.dart';
import 'package:ecoplus_app/roles/business/business_logic.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('business signs up and sees the home tab', (tester) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(800, 1800);
    addTearDown(tester.view.reset);
    final container = ProviderContainer();
    addTearDown(container.dispose);

    await tester.pumpWidget(UncontrolledProviderScope(
      container: container,
      child: MaterialApp(theme: buildTheme(Brightness.light), home: const BusinessApp()),
    ));
    await tester.pumpAndSettle();

    expect(find.text('افتح حساب البيزنس'), findsOneWidget);
    container.read(bizOnboardedProvider.notifier).done();
    await tester.pumpAndSettle();

    expect(find.text('الاستلام الجاي'), findsOneWidget);
    expect(container.read(businessProvider).balance, 1240);
  });
}
