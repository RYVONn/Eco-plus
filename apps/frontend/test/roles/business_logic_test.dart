import 'package:ecoplus_app/roles/business/business_logic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimate uses price per kg, points use factors', () {
    expect(estimate([6, 0, 4, 0]), 60);
    expect(pointsOf([4, 2, 3, 0]), closeTo(4 + 1.2 + 1.5, 1e-9));
  });

  test('cash arrives only at weighing, from the weighed amount', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(businessProvider.notifier);
    final id = n.createPickup(items: [10, 0, 0, 0], branch: 0, whenAr: 'اليوم', whenEn: 'Today', reward: Reward.cash);
    n.advance(id);
    n.advance(id);
    expect(c.read(businessProvider).balance, 1240);
    n.advance(id);
    expect(c.read(businessProvider).balance, 1240 + 9 * 8);
    n.advance(id);
    expect(c.read(businessProvider).balance, 1240 + 72);
  });

  test('points reward credits points and not cash', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(businessProvider.notifier);
    final id = n.createPickup(items: [10, 0, 0, 0], branch: 0, whenAr: 'اليوم', whenEn: 'Today', reward: Reward.points);
    for (var i = 0; i < 3; i++) {
      n.advance(id);
    }
    expect(c.read(businessProvider).balance, 1240);
    expect(c.read(businessProvider).points, 420 + 9);
  });

  test('withdraw cannot exceed the balance', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(businessProvider.notifier);
    expect(n.withdraw(5000), isFalse);
    expect(n.withdraw(200), isTrue);
    expect(c.read(businessProvider).balance, 1040);
  });
}
