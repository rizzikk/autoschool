import 'package:autoschool_client/domain/entities.dart';
import 'package:autoschool_client/domain/entity_def.dart';
import 'package:autoschool_client/domain/field_codec.dart';
import 'package:autoschool_client/models/pb_record.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('validateField: правила описаны в EntityDef', () {
    final phone = cadetsDef.field('phone')!;
    final name = cadetsDef.field('full_name')!;
    final rating = lessonsDef.field('rating')!;

    test('обязательное поле не может быть пустым или из одних пробелов', () {
      expect(validateField(name, ''), 'Обязательное поле');
      expect(validateField(name, '   '), 'Обязательное поле');
      expect(validateField(name, null), 'Обязательное поле');
    });

    test('телефон проверяется по шаблону +7 и десять цифр', () {
      expect(validateField(phone, '+79991234567'), isNull);
      expect(validateField(phone, '89991234567'), phoneMessage);
      expect(validateField(phone, '+7999123'), phoneMessage);
    });

    test('необязательное числовое поле: пусто можно, диапазон проверяется', () {
      expect(validateField(rating, ''), isNull);
      expect(validateField(rating, '5'), isNull);
      expect(validateField(rating, '6'), 'Не больше 5');
      expect(validateField(rating, '0'), 'Не меньше 1');
      expect(validateField(rating, 'abc'), 'Введите целое число');
    });

    test('поле-связь: без выбора — ошибка, с выбором — нет', () {
      final category = cadetsDef.field('category')!;
      expect(validateField(category, null), 'Выберите значение из списка');
      expect(validateField(category, 'cat1'), isNull);
    });

    test('номер автомобиля: русские буквы по образцу', () {
      final plate = carsDef.field('plate')!;
      expect(validateField(plate, 'А123ВС77'), isNull);
      expect(validateField(plate, 'A123BC77'), plateMessage,
          reason: 'латинские буквы не подходят');
    });

    test('дата в будущем запрещена там, где это задано полем', () {
      final birth = cadetsDef.field('birth_date')!;
      expect(validateField(birth, DateTime(2000, 1, 1)), isNull);
      expect(validateField(birth, DateTime.now().add(const Duration(days: 2))),
          'Дата не может быть в будущем');
    });
  });

  group('encodeField / decodeField: форма ⇄ тело запроса', () {
    test('число из текста, пустое — null', () {
      final price = categoriesDef.field('price')!;
      expect(encodeField(price, ' 38000 '), 38000);
      expect(encodeField(price, ''), isNull);
    });

    test('дата уходит как «ГГГГ-ММ-ДД», момент времени — в UTC', () {
      final birth = cadetsDef.field('birth_date')!;
      expect(
          encodeField(birth, DateTime(2001, 4, 9)), startsWith('2001-04-09'));
      final starts = lessonsDef.field('starts_at')!;
      final encoded = encodeField(starts, DateTime(2026, 5, 4, 10, 30));
      expect(encoded, isA<String>());
      expect(encoded as String, endsWith('Z'));
    });

    test('связь «многие ко многим» кодируется списком', () {
      final cats = instructorsDef.field('categories')!;
      expect(encodeField(cats, ['a', 'b']), ['a', 'b']);
      expect(
          decodeField(
              cats,
              const PbRecord({
                'categories': ['a', 'b']
              })),
          ['a', 'b']);
    });

    test('тип поля связи совпадает с описанием', () {
      expect(instructorsDef.field('categories')!.multi, isTrue);
      expect(instructorsDef.field('categories')!.type, FieldType.relation);
    });
  });
}
