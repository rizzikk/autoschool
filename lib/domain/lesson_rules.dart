import '../core/api_exceptions.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../util/format.dart';

const minLessonMinutes = 30;
const maxLessonMinutes = 180;

String? validateLessonTimes(DateTime? start, DateTime? end) {
  if (start == null || end == null) return null;
  final minutes = end.difference(start).inMinutes;
  if (minutes < minLessonMinutes) {
    return 'Занятие должно длиться не меньше $minLessonMinutes минут '
        'и заканчиваться позже начала.';
  }
  if (minutes > maxLessonMinutes) {
    return 'Занятие не может быть длиннее ${maxLessonMinutes ~/ 60} часов.';
  }
  return null;
}

Map<String, String> findBusyConflicts(
  List<BusySlot> slots, {
  String? selfId,
  required DateTime start,
  required DateTime end,
  String? instructor,
  String? car,
  String? cadet,
}) {
  final errors = <String, String>{};
  for (final s in slots) {
    if (s.id == selfId || !s.overlaps(start, end)) continue;
    if (instructor != null && s.instructor == instructor) {
      errors['instructor'] = 'Инструктор в это время занят другим занятием.';
    }
    if (car != null && s.car == car) {
      errors['car'] = 'Автомобиль в это время занят другим занятием.';
    }
    if (cadet != null && s.cadet == cadet) {
      errors['cadet'] = 'У курсанта в это время уже есть занятие.';
    }
  }
  return errors;
}

bool medicalValidOn(PbRecord certificate, DateTime day) {
  final from = certificate.date('issued_at');
  final to = certificate.date('valid_until');
  if (from == null || to == null) return false;
  final d = DateTime.utc(day.year, day.month, day.day);
  return !d.isBefore(from) && !d.isAfter(to);
}

Future<void> validateLessonBeforeSave(
  RecordRepository repo,
  Map<String, dynamic> body,
  String? id,
) async {
  final start = parsePbDate(body['starts_at']);
  final end = parsePbDate(body['ends_at']);
  final errors = <String, String>{};

  final timeError = validateLessonTimes(start, end);
  if (timeError != null) errors['ends_at'] = timeError;
  if (errors.isNotEmpty || start == null || end == null) {
    if (errors.isNotEmpty) {
      throw ValidationException(
          'Занятие не сохранено: проверьте поля.', errors);
    }
    return;
  }
  if (body['status'] == 'cancelled') return;

  final cadetId = '${body['cadet'] ?? ''}';
  final instructorId = '${body['instructor'] ?? ''}';
  final carId = '${body['car'] ?? ''}';

  final cadet = cadetId.isEmpty ? null : await repo.find('cadets', cadetId);
  final instructor = instructorId.isEmpty
      ? null
      : await repo.find('instructors', instructorId);
  final car = carId.isEmpty ? null : await repo.find('cars', carId);

  if (cadet != null) {
    final category = cadet.rel('category');
    if (car != null) {
      if (car.rel('category') != category) {
        errors['car'] =
            'Категория автомобиля не совпадает с категорией курсанта.';
      } else if (car.str('status') != 'active') {
        errors['car'] =
            'Автомобиль сейчас недоступен (обслуживание или списан).';
      }
    }
    if (instructor != null &&
        !instructor.ids('categories').contains(category)) {
      errors['instructor'] = 'Инструктор не преподаёт эту категорию.';
    }
    final certs = await repo.listAll('medical_certificates',
        where: And([Eq('cadet', cadet.id), const Eq('deleted', false)]));
    if (!certs.any((c) => medicalValidOn(c, start.toLocal()))) {
      errors['cadet'] =
          'У курсанта нет действующей медицинской справки на эту дату.';
    }
  }
  if (errors.isNotEmpty) {
    throw ValidationException('Занятие не сохранено: проверьте поля.', errors);
  }

  final slots = await repo.busy(
    from: start,
    to: end,
    instructor: instructorId,
    car: carId,
    cadet: cadetId,
  );
  final busy = findBusyConflicts(slots,
      selfId: id,
      start: start,
      end: end,
      instructor: instructorId,
      car: carId,
      cadet: cadetId);
  if (busy.isNotEmpty) {
    throw ConflictException('Время занято: выберите другое.', busy);
  }
}
