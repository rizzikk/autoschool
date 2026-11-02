import 'package:autoschool_client/domain/progress.dart';
import 'package:autoschool_client/models/pb_record.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/records.dart';

void main() {
  final now = DateTime(2026, 6, 15);
  final category = rec({'practice_hours': 2, 'price': 30000});
  final certificate = rec({
    'issued_at': '2026-01-01 00:00:00.000Z',
    'valid_until': '2027-01-01 00:00:00.000Z',
  });
  List<PbRecord> lessonsDone(int count) => [
        for (var i = 0; i < count; i++)
          rec({
            'status': 'done',
            'starts_at': utc(2026, 5, 1 + i, 7),
            'ends_at': utc(2026, 5, 1 + i, 8),
          })
      ];

  CadetProgress compute({
    int doneLessons = 2,
    bool theory = true,
    bool ground = true,
    int paid = 30000,
    bool withPayments = true,
    bool medical = true,
  }) =>
      computeProgress(
        category: category,
        lessons: lessonsDone(doneLessons),
        exams: [
          rec({'type': 'theory', 'result': theory ? 'passed' : 'failed'}),
          rec({'type': 'ground', 'result': ground ? 'passed' : 'scheduled'}),
        ],
        certificates: medical ? [certificate] : const [],
        payments: withPayments
            ? [
                rec({'amount': paid})
              ]
            : null,
        now: now,
      );

  group('computeProgress: допуск к итоговому экзамену', () {
    test('все условия выполнены — допущен', () {
      final p = compute();
      expect(p.admitted, isTrue);
      expect(p.practiceMinutes, 120);
      expect(p.practiceFraction, 1.0);
      expect(p.failedCount, 0);
    });

    test('не хватает часов вождения — не допущен, видно долю', () {
      final p = compute(doneLessons: 1);
      expect(p.admitted, isFalse);
      expect(p.practiceFraction, 0.5);
    });

    test('не сдан экзамен на площадке — не допущен', () {
      expect(compute(ground: false).admitted, isFalse);
    });

    test('оплачено не полностью — не допущен', () {
      expect(compute(paid: 29999).admitted, isFalse);
    });

    test('нет действующей справки — не допущен', () {
      expect(compute(medical: false).admitted, isFalse);
    });

    test('инструктор не видит платежей: оплата не проверена, но не провалена',
        () {
      final p = compute(withPayments: false);
      expect(p.hasUnknown, isTrue);
      expect(p.admitted, isTrue,
          reason: 'непроверенное условие не считается невыполненным');
    });

    test('удалённые и отменённые занятия в часы не входят', () {
      final p = computeProgress(
        category: category,
        lessons: [
          rec({
            'status': 'done',
            'deleted': true,
            'starts_at': utc(2026, 5, 1, 7),
            'ends_at': utc(2026, 5, 1, 8),
          }),
          rec({
            'status': 'cancelled',
            'starts_at': utc(2026, 5, 2, 7),
            'ends_at': utc(2026, 5, 2, 8),
          }),
        ],
        exams: const [],
        certificates: [certificate],
        payments: const [],
        now: now,
      );
      expect(p.practiceMinutes, 0);
    });
  });
}
