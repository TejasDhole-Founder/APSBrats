import 'package:apsbrat_frontend/features/onboarding/presentation/screens/onboarding_socials_screen.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('the birthday is sent the way the server reads dates', () {
    expect(apiDob('10/01/2006'), '2006-01-10');
    expect(apiDob(' 31/12/1999 '), '1999-12-31');
  });

  test('an older draft already in server form still works', () {
    expect(apiDob('2006-01-10'), '2006-01-10');
  });

  test('blank or unreadable is left out instead of failing signup', () {
    expect(apiDob(''), isNull);
    expect(apiDob('31/02/2006'), isNull);
    expect(apiDob('soon'), isNull);
  });
}
