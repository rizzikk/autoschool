import 'package:autoschool_client/domain/report.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/records.dart';

void main() {
  group('buildReport', () {
    final instructor = rec({'full_name': 'Кузнецов А. С.'});
    final report = buildReport(
      from: DateTime(2026, 5, 1),
      to: DateTime(2026, 6, 30),
      lessons: [
        rec({
          'status': 'done',
          'starts_at': utc(2026, 5, 4, 7),
          'ends_at': utc(2026, 5, 4, 8, 30),
        }, {
          'instructor': [instructor]
        }),
        rec({
          'status': 'done',
          'starts_at': utc(2026, 5, 5, 7),
          'ends_at': utc(2026, 5, 5, 8),
        }, {
          'instructor': [instructor]
        }),
        rec({'status': 'cancelled', 'starts_at': utc(2026, 5, 6, 7)}),
        rec({'status': 'planned', 'starts_at': utc(2026, 6, 6, 7)}),
        rec({
          'status': 'done',
          'deleted': true,
          'starts_at': utc(2026, 5, 7, 7),
          'ends_at': utc(2026, 5, 7, 8),
        }),
      ],
      payments: [
        rec({'amount': 10000, 'paid_at': '2026-06-02 00:00:00.000Z'}),
        rec({'amount': 5000, 'paid_at': '2026-05-20 00:00:00.000Z'}),
        rec({'amount': 7000, 'paid_at': '2026-05-21 00:00:00.000Z'}),
      ],
      exams: [
        rec({'result': 'passed'}),
        rec({'result': 'failed'}),
        rec({'result': 'scheduled'}),
      ],
      cadets: [
        rec({'status': 'studying'}),
        rec({'status': 'studying'}),
        rec({'status': 'graduated'}),
      ],
    );

    test('занятия считаются по статусам, удалённые не входят', () {
      expect(report.lessonsByStatus['done'], 2);
      expect(report.lessonsByStatus['cancelled'], 1);
      expect(report.lessonsByStatus['planned'], 1);
      expect(report.lessonsTotal, 4);
    });

    test('часы вождения: в сумме и по инструкторам', () {
      expect(report.drivingMinutes, 150);
      expect(report.hoursByInstructor['Кузнецов А. С.'], 150);
    });

    test('выручка по месяцам по возрастанию и общая сумма', () {
      expect(report.revenueByMonth.keys.toList(), ['2026-05', '2026-06']);
      expect(report.revenueByMonth['2026-05'], 12000);
      expect(report.revenueTotal, 22000);
    });

    test('сдаваемость считается среди проведённых экзаменов', () {
      expect(report.examsTotal, 2);
      expect(report.examsPassed, 1);
      expect(report.passRate, 0.5);
    });

    test('курсанты по статусам', () {
      expect(report.cadetsByStatus, {'studying': 2, 'graduated': 1});
    });
  });

  group('buildCsv и ярлыки', () {
    test('значения с «;», кавычками и переводом строки берутся в кавычки', () {
      final csv = buildCsv([
        ['a', 'б;в', 'г"д'],
        ['1', 'x\ny', '']
      ]);
      expect(csv, 'a;"б;в";"г""д"\r\n1;"x\ny";');
    });

    test('ярлык месяца', () {
      expect(monthLabel('2026-10'), 'окт 2026');
      expect(monthLabel('2026-01'), 'янв 2026');
    });
  });
}
