import 'package:autoschool_client/repositories/record_repository.dart';
import 'package:autoschool_client/screens/book_lesson_screen.dart';
import 'package:autoschool_client/screens/schedule_screen.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/records.dart';

void main() {
  group('candidateStarts: сетка времени для записи', () {
    final day = DateTime(2026, 9, 7);

    test('шаг 30 минут, занятие не заканчивается позже конца дня', () {
      final starts = candidateStarts(day, 60);
      expect(starts.first, DateTime(2026, 9, 7, bookingDayStartHour));
      expect(starts.last, DateTime(2026, 9, 7, bookingDayEndHour - 1));
      expect(starts[1].difference(starts[0]), const Duration(minutes: 30));
    });

    test('чем длиннее занятие, тем короче список вариантов', () {
      expect(candidateStarts(day, 120).length,
          lessThan(candidateStarts(day, 60).length));
    });
  });

  group('slotUnavailableReason: почему время недоступно', () {
    final now = DateTime(2026, 9, 7, 9);
    final busy = [
      BusySlot(
        id: 's1',
        start: DateTime(2026, 9, 7, 12).toUtc(),
        end: DateTime(2026, 9, 7, 13).toUtc(),
        instructor: 'i1',
        car: 'c9',
        cadet: 'k9',
      ),
    ];

    String? reason(DateTime start,
            {String instructor = 'i1', String car = 'c1'}) =>
        slotUnavailableReason(
          start: start,
          minutes: 60,
          busy: busy,
          instructor: instructor,
          car: car,
          cadet: 'k1',
          now: now,
        );

    test('прошедшее и слишком близкое время', () {
      expect(reason(DateTime(2026, 9, 7, 8)), contains('прошло'));
      expect(reason(DateTime(2026, 9, 7, 9, 15)), contains('слишком скоро'));
    });

    test('инструктор занят', () {
      expect(reason(DateTime(2026, 9, 7, 12, 30)), 'Инструктор занят');
    });

    test('автомобиль занят у другого инструктора', () {
      expect(reason(DateTime(2026, 9, 7, 12, 30), instructor: 'i2', car: 'c9'),
          'Автомобиль занят');
    });

    test('свободное время — причины нет', () {
      expect(reason(DateTime(2026, 9, 7, 15)), isNull);
    });
  });

  group('groupLessonsByDay: расписание недели', () {
    test('занятия раскладываются по дням и сортируются по времени', () {
      final monday = DateTime(2026, 9, 7);
      final byDay = groupLessonsByDay([
        rec({
          'id': 'b',
          'starts_at': DateTime(2026, 9, 9, 15).toUtc().toIso8601String()
        }),
        rec({
          'id': 'a',
          'starts_at': DateTime(2026, 9, 9, 8).toUtc().toIso8601String()
        }),
        rec({
          'id': 'x',
          'starts_at': DateTime(2026, 9, 14, 8).toUtc().toIso8601String()
        }),
      ], monday);
      expect(byDay.length, 7);
      expect(byDay[2].map((l) => l.id), ['a', 'b']);
      expect(byDay.expand((d) => d).length, 2,
          reason: 'занятие следующей недели в эту не попадает');
    });
  });
}
