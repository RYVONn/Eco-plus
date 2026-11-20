import 'package:ecoplus_app/roles/employee/employee_logic.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('points are weight x factor x level, cash is weight x price', () {
    expect(pointsFor([3, 2, 0, 0], 1.2), closeTo((3 * 1.0 + 2 * 0.6) * 1.2, 1e-9));
    expect(payoutFor([6, 0, 4, 0]), 6 * 8 + 4 * 3);
  });

  test('saving weights is idempotent and fills the matching batch', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(employeeProvider.notifier);
    final before = c.read(employeeProvider).batches[0].kg;
    expect(n.saveWeights(1051, [3, 2, 0, 0]), isTrue);
    expect(n.saveWeights(1051, [3, 2, 0, 0]), isFalse);
    final s = c.read(employeeProvider);
    expect(s.batches[0].kg, before + 3);
    expect(s.ledger, 14);
    expect(s.count(ShipStatus.weighed), 1);
  });

  test('a rejected shipment cannot be weighed', () {
    final c = ProviderContainer();
    addTearDown(c.dispose);
    final n = c.read(employeeProvider.notifier);
    n.reject(1050);
    expect(n.saveWeights(1050, [0, 4, 3, 0]), isFalse);
  });
}
