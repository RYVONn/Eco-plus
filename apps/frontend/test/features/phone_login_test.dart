import 'package:ecoplus_app/features/auth/phone_login_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('normalizes Egyptian mobile numbers', () {
    expect(normalizeEgyptPhone('01012345678'), '+201012345678');
    expect(normalizeEgyptPhone('+201012345678'), '+201012345678');
    expect(normalizeEgyptPhone('0101 234 5678'), '+201012345678');
    expect(normalizeEgyptPhone('0212345678'), isNull);
    expect(normalizeEgyptPhone('abc'), isNull);
  });
}
