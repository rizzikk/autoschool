import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:autoschool_client/domain/lesson_rules.dart';
import 'package:autoschool_client/repositories/in_memory_repository.dart';
import 'package:autoschool_client/repositories/record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/records.dart';

void main() {
  group('validateLessonTimes: длительность занятия', () {
    final start = DateTime(2026, 5, 4, 10);

    test('меньше 30 минут и конец раньше начала — ошибка', () {
      expect(validateLessonTimes(start, start.add(const Duration(minutes: 20))),
          contains('не меньше 30 минут'));
      expect(
          validateLessonTimes(start, start.subtract(const Duration(hours: 1))),
          isNotNull);
    });

    test('больше трёх часов — ошибка', () {
      expect(validateLessonTimes(start, start.add(const Duration(hours: 4))),
          contains('3 часов'));
    });

    test('граничные значения 30 и 180 минут допустимы', () {
      expect(validateLessonTimes(start, start.add(const Duration(minutes: 30))),
          isNull);
      expect(
          validateLessonTimes(start, start.add(const Duration(minutes: 180))),
          isNull);
    });

    test('пока одно из времён не выбрано, ошибки нет', () {
      expect(validateLessonTimes(null, start), isNull);
    });
  });

  group('findBusyConflicts: пересечение интервалов', () {
    final slot = BusySlot(
      id: 's1',
      start: DateTime.utc(2026, 5, 4, 7),
      end: DateTime.utc(2026, 5, 4, 8),
      instructor: 'i1',
      car: 'c1',
      cadet: 'k1',
    );

    test('занятое время инструктора, автомобиля и курсанта', () {
      final errors = findBusyConflicts([slot],
          start: DateTime.utc(2026, 5, 4, 7, 30),
          end: DateTime.utc(2026, 5, 4, 8, 30),
          instructor: 'i1',
          car: 'c1',
          cadet: 'k1');
      expect(errors.keys, containsAll(['instructor', 'car', 'cadet']));
    });

    test('занятия «встык» не пересекаются', () {
      final errors = findBusyConflicts([slot],
          start: DateTime.utc(2026, 5, 4, 8),
          end: DateTime.utc(2026, 5, 4, 9),
          instructor: 'i1');
      expect(errors, isEmpty);
    });

    test('другой инструктор в то же время — не конфликт', () {
      final errors = findBusyConflicts([slot],
          start: DateTime.utc(2026, 5, 4, 7),
          end: DateTime.utc(2026, 5, 4, 8),
          instructor: 'i2');
      expect(errors, isEmpty);
    });

    test('при изменении занятия оно не конфликтует само с собой', () {
      final errors = findBusyConflicts([slot],
          selfId: 's1',
          start: DateTime.utc(2026, 5, 4, 7),
          end: DateTime.utc(2026, 5, 4, 8),
          instructor: 'i1');
      expect(errors, isEmpty);
    });
  });

  group('medicalValidOn: справка действует в день занятия', () {
    final cert = rec({
      'issued_at': '2026-01-10 00:00:00.000Z',
      'valid_until': '2027-01-10 00:00:00.000Z',
    });

    test('внутри срока и в крайние дни', () {
      expect(medicalValidOn(cert, DateTime(2026, 6, 1)), isTrue);
      expect(medicalValidOn(cert, DateTime(2026, 1, 10)), isTrue);
      expect(medicalValidOn(cert, DateTime(2027, 1, 10)), isTrue);
    });

    test('до выдачи и после окончания не действует', () {
      expect(medicalValidOn(cert, DateTime(2026, 1, 9)), isFalse);
      expect(medicalValidOn(cert, DateTime(2027, 1, 11)), isFalse);
    });
  });

  group('validateLessonBeforeSave: проверки перед отправкой на сервер', () {
    InMemoryRepository repo() => InMemoryRepository(data: {
          'cadets': [
            {'id': 'k1', 'category': 'catB'}
          ],
          'instructors': [
            {
              'id': 'i1',
              'categories': ['catB']
            },
            {
              'id': 'i2',
              'categories': ['catA']
            },
          ],
          'cars': [
            {'id': 'c1', 'category': 'catB', 'status': 'active'},
            {'id': 'c2', 'category': 'catA', 'status': 'active'},
            {'id': 'c3', 'category': 'catB', 'status': 'service'},
          ],
          'medical_certificates': [
            {
              'id': 'm1',
              'cadet': 'k1',
              'issued_at': '2026-01-01 00:00:00.000Z',
              'valid_until': '2027-12-31 00:00:00.000Z',
            }
          ],
          'lessons': [
            {
              'id': 'l1',
              'cadet': 'k9',
              'instructor': 'i1',
              'car': 'c1',
              'status': 'planned',
              'starts_at': utc(2026, 9, 7, 7),
              'ends_at': utc(2026, 9, 7, 8),
            }
          ],
        });

    Map<String, dynamic> body({
      String instructor = 'i1',
      String car = 'c1',
      String status = 'planned',
      String start = '2026-09-07 09:00:00.000Z',
      String end = '2026-09-07 10:00:00.000Z',
    }) =>
        {
          'cadet': 'k1',
          'instructor': instructor,
          'car': car,
          'status': status,
          'starts_at': start,
          'ends_at': end,
        };

    test('корректное занятие проходит проверку', () async {
      await validateLessonBeforeSave(repo(), body(), null);
    });

    test('автомобиль другой категории — ошибка в поле «Автомобиль»', () async {
      await expectLater(
        validateLessonBeforeSave(repo(), body(car: 'c2'), null),
        throwsA(isA<ValidationException>()
            .having((e) => e.errors.keys, 'поля', contains('car'))),
      );
    });

    test('автомобиль на обслуживании — ошибка', () async {
      await expectLater(
        validateLessonBeforeSave(repo(), body(car: 'c3'), null),
        throwsA(isA<ValidationException>()
            .having((e) => e.errors['car'], 'car', contains('недоступен'))),
      );
    });

    test('инструктор без нужной категории — ошибка', () async {
      await expectLater(
        validateLessonBeforeSave(repo(), body(instructor: 'i2'), null),
        throwsA(isA<ValidationException>()
            .having((e) => e.errors.keys, 'поля', contains('instructor'))),
      );
    });

    test('время занято другим занятием инструктора — конфликт', () async {
      await expectLater(
        validateLessonBeforeSave(
            repo(),
            body(
                start: '2026-09-07 07:30:00.000Z',
                end: '2026-09-07 08:30:00.000Z'),
            null),
        throwsA(isA<ConflictException>()
            .having((e) => e.errors.keys, 'поля', contains('instructor'))),
      );
    });

    test('отменённое занятие на занятое время сохранить можно', () async {
      await validateLessonBeforeSave(
          repo(),
          body(
              status: 'cancelled',
              start: '2026-09-07 07:30:00.000Z',
              end: '2026-09-07 08:30:00.000Z'),
          null);
    });

    test('справка не действует на дату занятия — ошибка в поле «Курсант»',
        () async {
      await expectLater(
        validateLessonBeforeSave(
            repo(),
            body(
                start: '2028-02-01 09:00:00.000Z',
                end: '2028-02-01 10:00:00.000Z'),
            null),
        throwsA(isA<ValidationException>()
            .having((e) => e.errors.keys, 'поля', contains('cadet'))),
      );
    });

    test('слишком короткое занятие — ошибка в поле «Окончание»', () async {
      await expectLater(
        validateLessonBeforeSave(
            repo(),
            body(
                start: '2026-09-07 09:00:00.000Z',
                end: '2026-09-07 09:10:00.000Z'),
            null),
        throwsA(isA<ValidationException>()
            .having((e) => e.errors.keys, 'поля', contains('ends_at'))),
      );
    });
  });
}
