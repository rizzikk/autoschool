import 'package:autoschool_client/repositories/conditions.dart';
import 'package:autoschool_client/repositories/pb_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('pbQuote', () {
    test('кавычка и обратная косая черта экранируются', () {
      expect(pbQuote("О'Брайен"), r"'О\'Брайен'");
      expect(pbQuote(r'a\b'), r"'a\\b'");
    });
  });

  group('searchVariants: LIKE в SQLite не различает регистр только у латиницы',
      () {
    test('для кириллицы строятся строчный и «с заглавной» варианты', () {
      expect(searchVariants('иван петров'),
          containsAll(['иван петров', 'Иван Петров']));
    });

    test('пустая строка не даёт вариантов', () {
      expect(searchVariants('   '), isEmpty);
    });
  });

  group('toPbFilter: дерево условий → строка фильтра PocketBase', () {
    test('пустое условие — пустая строка', () {
      expect(toPbFilter(null), '');
      expect(toPbFilter(const And([])), '');
    });

    test('равенство: строки в кавычках, логические значения без них', () {
      expect(toPbFilter(const Eq('status', 'studying')), "status = 'studying'");
      expect(toPbFilter(const Eq('deleted', false)), 'deleted = false');
    });

    test('«И» собирает условия в скобки', () {
      expect(
        toPbFilter(const And([Eq('deleted', false), Eq('car', 'c1')])),
        "(deleted = false && car = 'c1')",
      );
    });

    test('поиск по подстроке даёт «ИЛИ» из вариантов написания', () {
      expect(toPbFilter(const Like('full_name', 'абв')),
          "(full_name ~ 'абв' || full_name ~ 'Абв')");
    });

    test('многозначная связь и границы дат', () {
      expect(
          toPbFilter(const Has('categories', 'b1')), "categories.id ?= 'b1'");
      expect(toPbFilter(const Gte('starts_at', '2026-05-01')),
          "starts_at >= '2026-05-01'");
      expect(toPbFilter(const Lte('starts_at', '2026-05-31')),
          "starts_at <= '2026-05-31'");
    });

    test('вложенные условия: поиск «ИЛИ» внутри «И»', () {
      final f = toPbFilter(const And([
        Eq('deleted', false),
        Or([Like('plate', '123'), Like('model', '123')]),
      ]));
      expect(f, startsWith('(deleted = false && '));
      expect(f, contains('plate ~ \'123\''));
      expect(f, contains('model ~ \'123\''));
    });
  });
}
