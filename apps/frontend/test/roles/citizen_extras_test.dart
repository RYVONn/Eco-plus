import 'package:ecoplus_app/app/theme.dart';
import 'package:ecoplus_app/roles/citizen/citizen_app.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

Future<ProviderContainer> _open(WidgetTester tester, {required bool onboarded}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = const Size(800, 1800);
  addTearDown(tester.view.reset);
  final container = ProviderContainer();
  addTearDown(container.dispose);
  if (onboarded) container.read(citizenOnboardedProvider.notifier).done();
  await tester.pumpWidget(UncontrolledProviderScope(
    container: container,
    child: MaterialApp(theme: buildTheme(Brightness.light), home: const CitizenApp()),
  ));
  await tester.pumpAndSettle();
  return container;
}

void main() {
  testWidgets('preview sign-in goes phone, code, profile, permissions', (tester) async {
    await _open(tester, onboarded: false);
    await tester.tap(find.text('تخطي'));
    await tester.pumpAndSettle();
    expect(find.text('رقم موبايلك'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '01012345678');
    await tester.pump();
    await tester.tap(find.text('ابعت الكود'));
    await tester.pumpAndSettle();
    expect(find.text('اكتب الكود'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, '1234');
    await tester.pump();
    await tester.tap(find.text('تأكيد'));
    await tester.pumpAndSettle();
    expect(find.text('عرّفنا بيك'), findsOneWidget);

    await tester.enterText(find.byType(TextField).first, 'منى');
    await tester.pump();
    await tester.tap(find.text('التالي'));
    await tester.pumpAndSettle();
    expect(find.text('كام صلاحية بسيطة'), findsOneWidget);
  });

  testWidgets('map tab shows nearby places and a selected point', (tester) async {
    await _open(tester, onboarded: true);
    await tester.tap(find.text('الخريطة'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أماكن قريبة منك'), findsOneWidget);
    await tester.tap(find.text('زجاج'));
    await tester.pumpAndSettle();
    expect(find.textContaining('أماكن قريبة منك'), findsOneWidget);
  });

  testWidgets('rewards preview opens from points and lists the catalogue', (tester) async {
    await _open(tester, onboarded: true);
    await tester.tap(find.text('نقاطي').last);
    await tester.pumpAndSettle();
    final btn = find.text('المكافآت (معاينة)');
    await tester.ensureVisible(btn);
    await tester.pumpAndSettle();
    await tester.tap(btn);
    await tester.pumpAndSettle();
    expect(find.text('قهوة مجانية'), findsOneWidget);
    await tester.tap(find.text('ازرع شجرة'));
    await tester.pumpAndSettle();
    expect(find.text('استبدل'), findsOneWidget);
  });
}
