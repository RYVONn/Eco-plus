import 'package:ecoplus_app/roles/buyer/buyer_logic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  ProviderContainer make() {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    return c;
  }

  test('independent recyclers see only small lots, factories see all', () {
    final c = make();
    expect(c.read(buyerProvider).market(-1).every((l) => l.min <= 100), isTrue);
    c.read(buyerProvider.notifier).signup('x', true);
    expect(c.read(buyerProvider).market(-1).length, lots.length);
  });

  test('order total is weight x price plus delivery', () {
    const o = BuyOrder(id: 1, lot: 1, qty: 500, delivery: true, stage: 0);
    expect(o.total, 500 * 11 + deliveryFee);
  });

  test('order outside lot limits is rejected', () {
    final c = make();
    final n = c.read(buyerProvider.notifier);
    expect(n.placeOrder(1, 100, false), -1);
    expect(n.placeOrder(1, 5000, false), -1);
    expect(n.placeOrder(1, 500, false), 2032);
  });

  test('spend grows only when the order is delivered', () {
    final c = make();
    final n = c.read(buyerProvider.notifier);
    final id = n.placeOrder(4, 500, false);
    n.advance(id);
    n.advance(id);
    expect(c.read(buyerProvider).spent, 5800);
    n.advance(id);
    expect(c.read(buyerProvider).spent, 5800 + 500 * 4.5);
  });
}
