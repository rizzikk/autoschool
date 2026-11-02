import '../models/pb_record.dart';
import 'lesson_rules.dart';

class ProgressCondition {
  const ProgressCondition(this.title, this.detail, {required this.ok});

  final String title;
  final String detail;

  final bool? ok;
}

class CadetProgress {
  const CadetProgress({
    required this.practiceMinutes,
    required this.practiceRequiredMinutes,
    required this.plannedMinutes,
    required this.conditions,
  });

  final int practiceMinutes;
  final int practiceRequiredMinutes;
  final int plannedMinutes;
  final List<ProgressCondition> conditions;

  double get practiceFraction => practiceRequiredMinutes == 0
      ? 0
      : (practiceMinutes / practiceRequiredMinutes).clamp(0, 1).toDouble();

  bool get admitted => conditions.every((c) => c.ok != false);

  bool get hasUnknown => conditions.any((c) => c.ok == null);

  int get failedCount => conditions.where((c) => c.ok == false).length;
}

int lessonMinutes(PbRecord lesson) {
  final s = lesson.date('starts_at'), e = lesson.date('ends_at');
  if (s == null || e == null) return 0;
  final m = e.difference(s).inMinutes;
  return m < 0 ? 0 : m;
}

String _hours(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return m == 0 ? '$h ч' : '$h ч $m мин';
}

bool _passed(List<PbRecord> exams, String type) => exams.any(
    (e) => !e.deleted && e.str('type') == type && e.str('result') == 'passed');

CadetProgress computeProgress({
  required PbRecord category,
  required List<PbRecord> lessons,
  required List<PbRecord> exams,
  required List<PbRecord> certificates,
  required List<PbRecord>? payments,
  DateTime? now,
}) {
  final today = now ?? DateTime.now();
  final active = lessons.where((l) => !l.deleted).toList();
  final done = active
      .where((l) => l.str('status') == 'done')
      .fold<int>(0, (sum, l) => sum + lessonMinutes(l));
  final planned = active
      .where((l) => l.str('status') == 'planned')
      .fold<int>(0, (sum, l) => sum + lessonMinutes(l));
  final required = category.integer('practice_hours') * 60;

  final medicalOk = certificates
      .where((c) => !c.deleted)
      .any((c) => medicalValidOn(c, today));

  bool? paidOk;
  var paid = 0;
  if (payments != null) {
    paid = payments
        .where((p) => !p.deleted)
        .fold<int>(0, (sum, p) => sum + p.integer('amount'));
    paidOk = paid >= category.integer('price');
  }

  return CadetProgress(
    practiceMinutes: done,
    practiceRequiredMinutes: required,
    plannedMinutes: planned,
    conditions: [
      ProgressCondition(
        'Вождение: ${_hours(required)}',
        'Проведено ${_hours(done)}, запланировано ещё ${_hours(planned)}',
        ok: done >= required,
      ),
      ProgressCondition(
        'Теоретический экзамен сдан',
        _passed(exams, 'theory') ? 'Сдан' : 'Не сдан',
        ok: _passed(exams, 'theory'),
      ),
      ProgressCondition(
        'Экзамен на площадке сдан',
        _passed(exams, 'ground') ? 'Сдан' : 'Не сдан',
        ok: _passed(exams, 'ground'),
      ),
      ProgressCondition(
        'Обучение оплачено полностью',
        payments == null
            ? 'Оплату проверяет администратор'
            : 'Внесено $paid из ${category.integer('price')} ₽',
        ok: paidOk,
      ),
      ProgressCondition(
        'Медицинская справка действует',
        medicalOk ? 'Действует' : 'Нет действующей справки',
        ok: medicalOk,
      ),
    ],
  );
}
