import 'dart:convert';

import 'package:autoschool_client/core/jwt.dart';
import 'package:autoschool_client/core/session.dart';
import 'package:flutter_test/flutter_test.dart';

String fakeJwt(DateTime exp) {
  String part(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  return '${part({'alg': 'HS256'})}.'
      '${part({'exp': exp.millisecondsSinceEpoch ~/ 1000, 'id': 'u1'})}.sig';
}

void main() {
  group('jwtExpiry', () {
    test('срок действия читается из поля exp', () {
      final exp = DateTime.utc(2026, 7, 1, 12);
      expect(jwtExpiry(fakeJwt(exp))!.toUtc(), exp);
    });

    test('не-токен и повреждённый токен дают null, а не исключение', () {
      expect(jwtExpiry('просто строка'), isNull);
      expect(jwtExpiry('a.b.c'), isNull);
      expect(jwtExpiry(''), isNull);
    });
  });

  group('ApiSession.isExpiringSoon: токен обновляют заранее', () {
    final now = DateTime(2026, 7, 1, 12);

    test('до конца больше запаса — не пора', () {
      final s = ApiSession()
        ..accessToken = fakeJwt(now.add(const Duration(minutes: 30)));
      expect(s.isExpiringSoon(const Duration(minutes: 10), now: now), isFalse);
    });

    test('до конца меньше запаса или уже истёк — пора', () {
      final soon = ApiSession()
        ..accessToken = fakeJwt(now.add(const Duration(minutes: 5)));
      final expired = ApiSession()
        ..accessToken = fakeJwt(now.subtract(const Duration(minutes: 1)));
      expect(
          soon.isExpiringSoon(const Duration(minutes: 10), now: now), isTrue);
      expect(expired.isExpiringSoon(const Duration(minutes: 10), now: now),
          isTrue);
    });

    test('нет токена — обновлять нечего', () {
      expect(ApiSession().isExpiringSoon(const Duration(minutes: 10)), isFalse);
    });
  });
}
