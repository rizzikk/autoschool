import 'package:flutter/material.dart';

import '../auth/permissions.dart';
import '../core/api_exceptions.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../util/format.dart';
import 'entity_def.dart';
import 'lesson_rules.dart';

const cadetStatuses = {
  'studying': 'Обучается',
  'graduated': 'Выпускник',
  'expelled': 'Отчислен',
};
const carStatuses = {
  'active': 'В эксплуатации',
  'service': 'На обслуживании',
  'retired': 'Списан',
};
const transmissions = {'manual': 'Механика', 'auto': 'Автомат'};
const lessonKinds = {'ground': 'Площадка', 'city': 'Город'};
const lessonStatuses = {
  'planned': 'Запланировано',
  'done': 'Проведено',
  'cancelled': 'Отменено',
  'no_show': 'Неявка',
};
const examTypes = {'theory': 'Теория', 'ground': 'Площадка', 'city': 'Город'};
const examResults = {
  'scheduled': 'Назначен',
  'passed': 'Сдан',
  'failed': 'Не сдан',
  'no_show': 'Неявка',
};
const payMethods = {'cash': 'Наличные', 'card': 'Карта', 'transfer': 'Перевод'};
const payPurposes = {
  'tuition': 'Обучение',
  'retake': 'Пересдача',
  'extra_lesson': 'Доп. занятие',
};
const userRoles = {
  'cadet': 'Курсант',
  'instructor': 'Инструктор',
  'admin': 'Администратор',
};

const phonePattern = r'^\+7\d{10}$';
const phoneMessage = 'Формат: +7 и 10 цифр, например +79991234567';
const platePattern =
    r'^([АВЕКМНОРСТУХ]\d{3}[АВЕКМНОРСТУХ]{2}|\d{4}[АВЕКМНОРСТУХ]{2})\d{2,3}$';
const plateMessage = 'Номер русскими буквами АВЕКМНОРСТУХ, например А123ВС77';

String _lbl(Map<String, String> m, String key) => m[key] ?? key;
String _name(PbRecord? r) => r?.str('full_name') ?? '';

Future<void> _groupCheck(
    RecordRepository repo, Map<String, dynamic> body, String? id) async {
  final s = parsePbDate(body['starts_at']);
  final e = parsePbDate(body['ends_at']);
  if (s != null && e != null && !e.isAfter(s)) {
    throw const ValidationException('Группа не сохранена.',
        {'ends_at': 'Окончание обучения должно быть позже начала.'});
  }
}

Future<void> _medicalCheck(
    RecordRepository repo, Map<String, dynamic> body, String? id) async {
  final s = parsePbDate(body['issued_at']);
  final e = parsePbDate(body['valid_until']);
  if (s != null && e != null && e.isBefore(s)) {
    throw const ValidationException('Справка не сохранена.',
        {'valid_until': 'Срок действия не может быть раньше даты выдачи.'});
  }
}

Future<void> _setLessonStatus(
        RecordRepository repo, PbRecord r, String status) =>
    repo.update('lessons', r.id, {'status': status});

final lessonActions = <RowAction>[
  RowAction(
    label: 'Занятие проведено',
    icon: Icons.check_circle_outline,
    confirm: 'Отметить занятие проведённым?',
    success: 'Занятие отмечено проведённым',
    visible: (role, r) =>
        role != Role.cadet && r.str('status') == 'planned' && !r.deleted,
    run: (repo, r) => _setLessonStatus(repo, r, 'done'),
  ),
  RowAction(
    label: 'Неявка курсанта',
    icon: Icons.person_off_outlined,
    confirm: 'Отметить неявку курсанта?',
    success: 'Отмечена неявка',
    visible: (role, r) =>
        role != Role.cadet && r.str('status') == 'planned' && !r.deleted,
    run: (repo, r) => _setLessonStatus(repo, r, 'no_show'),
  ),
  RowAction(
    label: 'Отменить занятие',
    icon: Icons.event_busy_outlined,
    confirm: 'Отменить это занятие? Время освободится для других.',
    success: 'Занятие отменено',
    visible: (role, r) => r.str('status') == 'planned' && !r.deleted,
    run: (repo, r) => _setLessonStatus(repo, r, 'cancelled'),
  ),
];

const _catRel = RelationDef('categories', sort: 'code');

final EntityDef categoriesDef = EntityDef(
  collection: 'categories',
  path: '/categories',
  singular: 'категория',
  plural: 'Категории',
  accusative: 'категорию',
  icon: Icons.category_outlined,
  description: 'Категории прав, стоимость и объём обучения',
  defaultSort: 'code',
  defaultAscending: true,
  searchFields: const ['code', 'title'],
  titleOf: (r) => '${r.str('code')} — ${r.str('title')}',
  subtitleOf: (r) =>
      'от ${r.integer('min_age')} лет · ${fmtMoney(r.integer('price'))}',
  fields: const [
    FieldDef('code', 'Код', FieldType.text,
        required: true,
        min: 1,
        max: 4,
        pattern: r'^[A-Za-z0-9]{1,4}$',
        patternMessage: 'Латинские буквы и цифры, не больше 4',
        hint: 'Например, B'),
    FieldDef('title', 'Название', FieldType.text,
        required: true, min: 3, max: 80),
    FieldDef('min_age', 'Минимальный возраст', FieldType.integer,
        required: true, min: 14, max: 30),
    FieldDef('theory_hours', 'Часов теории', FieldType.integer,
        required: true, min: 1, max: 500),
    FieldDef('practice_hours', 'Часов вождения', FieldType.integer,
        required: true, min: 1, max: 500),
    FieldDef('price', 'Стоимость, ₽', FieldType.money,
        required: true, min: 1, max: 1000000),
    FieldDef('description', 'Описание', FieldType.multiline, max: 500),
  ],
  columns: [
    ColumnDef('Код', (r) => r.str('code'), sortField: 'code'),
    ColumnDef('Название', (r) => r.str('title'), sortField: 'title'),
    ColumnDef('Возраст', (r) => 'от ${r.integer('min_age')}',
        sortField: 'min_age', numeric: true),
    ColumnDef('Теория, ч', (r) => '${r.integer('theory_hours')}',
        sortField: 'theory_hours', numeric: true),
    ColumnDef('Вождение, ч', (r) => '${r.integer('practice_hours')}',
        sortField: 'practice_hours', numeric: true),
    ColumnDef('Стоимость', (r) => fmtMoney(r.integer('price')),
        sortField: 'price', numeric: true),
  ],
  related: const [
    RelatedDef('Курсанты категории', 'cadets', 'category'),
    RelatedDef('Автомобили категории', 'cars', 'category'),
  ],
);

final EntityDef cadetsDef = EntityDef(
  collection: 'cadets',
  path: '/cadets',
  singular: 'курсант',
  plural: 'Курсанты',
  accusative: 'курсанта',
  cadetLabel: 'Мой профиль',
  icon: Icons.school_outlined,
  description: 'Анкеты курсантов, статус обучения, категория',
  defaultSort: 'full_name',
  defaultAscending: true,
  expand: 'category',
  searchFields: const ['full_name', 'phone'],
  titleOf: (r) => r.str('full_name'),
  subtitleOf: (r) =>
      '${r.one('category')?.str('code') ?? ''} · ${_lbl(cadetStatuses, r.str('status'))}',
  fields: const [
    FieldDef('user', 'Учётная запись', FieldType.relation,
        required: true,
        adminOnly: true,
        relation:
            RelationDef('users', filter: Eq('role', 'cadet'), sort: 'email'),
        hint: 'Пользователь с ролью «курсант»'),
    FieldDef('full_name', 'ФИО', FieldType.text,
        required: true, min: 5, max: 100, hint: 'Фамилия Имя Отчество'),
    FieldDef('birth_date', 'Дата рождения', FieldType.date,
        required: true, noFuture: true),
    FieldDef('phone', 'Телефон', FieldType.phone,
        required: true, pattern: phonePattern, patternMessage: phoneMessage),
    FieldDef('category', 'Категория', FieldType.relation,
        required: true, adminOnly: true, relation: _catRel),
    FieldDef('status', 'Статус', FieldType.select,
        required: true,
        adminOnly: true,
        options: cadetStatuses,
        initial: 'studying'),
    FieldDef('enrolled_at', 'Дата зачисления', FieldType.date,
        required: true, adminOnly: true),
  ],
  columns: [
    ColumnDef('ФИО', (r) => r.str('full_name'), sortField: 'full_name'),
    ColumnDef('Телефон', (r) => r.str('phone')),
    ColumnDef('Категория', (r) => r.one('category')?.str('code') ?? '',
        sortField: 'category.code'),
    ColumnDef('Статус', (r) => _lbl(cadetStatuses, r.str('status')),
        sortField: 'status'),
    ColumnDef('Зачислен', (r) {
      final d = r.date('enrolled_at');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'enrolled_at'),
  ],
  filters: const [
    FilterDef('status', 'Статус', FilterKind.select, options: cadetStatuses),
    FilterDef('category', 'Категория', FilterKind.relation, relation: _catRel),
    FilterDef('from', 'Зачислен с', FilterKind.dateFrom, field: 'enrolled_at'),
    FilterDef('to', 'Зачислен по', FilterKind.dateTo, field: 'enrolled_at'),
  ],
  related: const [
    RelatedDef('Занятия', 'lessons', 'cadet', sort: '-starts_at'),
    RelatedDef('Экзамены', 'exams', 'cadet', sort: '-exam_date'),
    RelatedDef('Платежи', 'payments', 'cadet', sort: '-paid_at'),
    RelatedDef('Медицинская справка', 'medical_certificates', 'cadet'),
  ],
);

final EntityDef medicalDef = EntityDef(
  collection: 'medical_certificates',
  path: '/medical',
  singular: 'справка',
  plural: 'Медицинские справки',
  accusative: 'справку',
  icon: Icons.medical_services_outlined,
  description: 'Справки курсантов: срок действия определяет допуск к вождению',
  defaultSort: 'valid_until',
  defaultAscending: true,
  expand: 'cadet',
  searchFields: const ['number', 'clinic', 'cadet.full_name'],
  titleOf: (r) => 'Справка № ${r.str('number')}',
  subtitleOf: (r) => _name(r.one('cadet')),
  beforeSave: _medicalCheck,
  fields: const [
    FieldDef('cadet', 'Курсант', FieldType.relation,
        required: true, relation: RelationDef('cadets', sort: 'full_name')),
    FieldDef('number', 'Номер справки', FieldType.text,
        required: true, min: 4, max: 30),
    FieldDef('issued_at', 'Дата выдачи', FieldType.date,
        required: true, noFuture: true),
    FieldDef('valid_until', 'Действует до', FieldType.date, required: true),
    FieldDef('clinic', 'Медицинская организация', FieldType.text,
        required: true, min: 3, max: 120),
  ],
  columns: [
    ColumnDef('Курсант', (r) => _name(r.one('cadet')),
        sortField: 'cadet.full_name'),
    ColumnDef('Номер', (r) => r.str('number'), sortField: 'number'),
    ColumnDef('Выдана', (r) {
      final d = r.date('issued_at');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'issued_at'),
    ColumnDef('Действует до', (r) {
      final d = r.date('valid_until');
      if (d == null) return '';
      final expired = d.isBefore(DateTime.now());
      return expired ? '${fmtDate(d)} (истекла)' : fmtDate(d);
    }, sortField: 'valid_until'),
    ColumnDef('Организация', (r) => r.str('clinic')),
  ],
  filters: const [
    FilterDef('from', 'Действует с', FilterKind.dateFrom, field: 'valid_until'),
    FilterDef('to', 'Действует по', FilterKind.dateTo, field: 'valid_until'),
    FilterDef('cadet', 'Курсант', FilterKind.relation,
        relation: RelationDef('cadets', sort: 'full_name')),
  ],
);

final EntityDef instructorsDef = EntityDef(
  collection: 'instructors',
  path: '/instructors',
  singular: 'инструктор',
  plural: 'Инструкторы',
  accusative: 'инструктора',
  icon: Icons.badge_outlined,
  description: 'Инструкторы, их категории и стаж',
  defaultSort: 'full_name',
  defaultAscending: true,
  expand: 'categories',
  searchFields: const ['full_name', 'phone', 'license_no'],
  titleOf: (r) => r.str('full_name'),
  subtitleOf: (r) => r.many('categories').map((c) => c.str('code')).join(', '),
  fields: const [
    FieldDef('user', 'Учётная запись', FieldType.relation,
        required: true,
        relation: RelationDef('users',
            filter: Eq('role', 'instructor'), sort: 'email'),
        hint: 'Пользователь с ролью «инструктор»'),
    FieldDef('full_name', 'ФИО', FieldType.text,
        required: true, min: 5, max: 100),
    FieldDef('phone', 'Телефон', FieldType.phone,
        required: true, pattern: phonePattern, patternMessage: phoneMessage),
    FieldDef('experience_years', 'Стаж, лет', FieldType.integer,
        min: 0, max: 60),
    FieldDef('license_no', 'Водительское удостоверение', FieldType.text,
        required: true,
        pattern: r'^\d{4} \d{6}$',
        patternMessage: 'Формат: 4 цифры, пробел, 6 цифр (1234 567890)'),
    FieldDef('categories', 'Преподаваемые категории', FieldType.relation,
        required: true, multi: true, minItems: 1, relation: _catRel),
    FieldDef('hired_at', 'Принят на работу', FieldType.date,
        required: true, noFuture: true),
  ],
  columns: [
    ColumnDef('ФИО', (r) => r.str('full_name'), sortField: 'full_name'),
    ColumnDef('Телефон', (r) => r.str('phone')),
    ColumnDef('Стаж', (r) => '${r.integer('experience_years')} лет',
        sortField: 'experience_years', numeric: true),
    ColumnDef('Категории',
        (r) => r.many('categories').map((c) => c.str('code')).join(', ')),
    ColumnDef('Принят', (r) {
      final d = r.date('hired_at');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'hired_at'),
  ],
  filters: const [
    FilterDef('category', 'Категория', FilterKind.relation,
        field: 'categories', multi: true, relation: _catRel),
    FilterDef('from', 'Принят с', FilterKind.dateFrom, field: 'hired_at'),
    FilterDef('to', 'Принят по', FilterKind.dateTo, field: 'hired_at'),
  ],
  related: const [
    RelatedDef('Занятия', 'lessons', 'instructor', sort: '-starts_at'),
    RelatedDef('Кураторство групп', 'groups', 'curator'),
  ],
);

final EntityDef carsDef = EntityDef(
  collection: 'cars',
  path: '/cars',
  singular: 'автомобиль',
  plural: 'Автомобили',
  accusative: 'автомобиль',
  icon: Icons.directions_car_outlined,
  description: 'Учебные автомобили, пробег и сроки обслуживания',
  defaultSort: 'plate',
  defaultAscending: true,
  expand: 'category',
  searchFields: const ['plate', 'model'],
  titleOf: (r) => '${r.str('plate')} · ${r.str('model')}',
  subtitleOf: (r) => _lbl(carStatuses, r.str('status')),
  fields: const [
    FieldDef('plate', 'Госномер', FieldType.text,
        required: true,
        pattern: platePattern,
        patternMessage: plateMessage,
        hint: 'А123ВС77'),
    FieldDef('model', 'Марка и модель', FieldType.text,
        required: true, min: 2, max: 80),
    FieldDef('year', 'Год выпуска', FieldType.integer,
        required: true, min: 1990, max: 2100),
    FieldDef('category', 'Категория', FieldType.relation,
        required: true, relation: _catRel),
    FieldDef('transmission', 'Коробка передач', FieldType.select,
        required: true, options: transmissions),
    FieldDef('mileage', 'Пробег, км', FieldType.integer, min: 0, max: 2000000),
    FieldDef('status', 'Состояние', FieldType.select,
        required: true, options: carStatuses, initial: 'active'),
    FieldDef('next_service', 'Следующее ТО', FieldType.date),
  ],
  columns: [
    ColumnDef('Номер', (r) => r.str('plate'), sortField: 'plate'),
    ColumnDef('Модель', (r) => r.str('model'), sortField: 'model'),
    ColumnDef('Год', (r) => '${r.integer('year')}',
        sortField: 'year', numeric: true),
    ColumnDef('Категория', (r) => r.one('category')?.str('code') ?? '',
        sortField: 'category.code'),
    ColumnDef('КПП', (r) => _lbl(transmissions, r.str('transmission'))),
    ColumnDef('Пробег', (r) => '${r.integer('mileage')} км',
        sortField: 'mileage', numeric: true),
    ColumnDef('Состояние', (r) => _lbl(carStatuses, r.str('status')),
        sortField: 'status'),
    ColumnDef('ТО до', (r) {
      final d = r.date('next_service');
      return d == null ? '—' : fmtDate(d);
    }, sortField: 'next_service'),
  ],
  filters: const [
    FilterDef('category', 'Категория', FilterKind.relation, relation: _catRel),
    FilterDef('transmission', 'КПП', FilterKind.select, options: transmissions),
    FilterDef('status', 'Состояние', FilterKind.select, options: carStatuses),
    FilterDef('service_to', 'ТО не позже', FilterKind.dateTo,
        field: 'next_service'),
  ],
  related: const [
    RelatedDef('Занятия на автомобиле', 'lessons', 'car', sort: '-starts_at'),
  ],
);

final EntityDef groupsDef = EntityDef(
  collection: 'groups',
  path: '/groups',
  singular: 'группа',
  plural: 'Учебные группы',
  accusative: 'группу',
  icon: Icons.groups_outlined,
  description: 'Группы, куратор и состав (связь «многие ко многим»)',
  defaultSort: 'starts_at',
  defaultAscending: false,
  expand: 'category,curator,cadets',
  searchFields: const ['name'],
  titleOf: (r) => r.str('name'),
  subtitleOf: (r) =>
      '${r.one('category')?.str('code') ?? ''} · ${r.ids('cadets').length} курсантов',
  beforeSave: _groupCheck,
  fields: const [
    FieldDef('name', 'Название', FieldType.text,
        required: true, min: 2, max: 60),
    FieldDef('category', 'Категория', FieldType.relation,
        required: true, relation: _catRel),
    FieldDef('curator', 'Куратор', FieldType.relation,
        relation: RelationDef('instructors', sort: 'full_name')),
    FieldDef('starts_at', 'Начало обучения', FieldType.date, required: true),
    FieldDef('ends_at', 'Окончание обучения', FieldType.date, required: true),
    FieldDef('cadets', 'Состав группы', FieldType.relation,
        multi: true, relation: RelationDef('cadets', sort: 'full_name')),
  ],
  columns: [
    ColumnDef('Название', (r) => r.str('name'), sortField: 'name'),
    ColumnDef('Категория', (r) => r.one('category')?.str('code') ?? '',
        sortField: 'category.code'),
    ColumnDef('Куратор', (r) => _name(r.one('curator')),
        sortField: 'curator.full_name'),
    ColumnDef('Начало', (r) {
      final d = r.date('starts_at');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'starts_at'),
    ColumnDef('Окончание', (r) {
      final d = r.date('ends_at');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'ends_at'),
    ColumnDef('Курсантов', (r) => '${r.ids('cadets').length}', numeric: true),
  ],
  filters: const [
    FilterDef('category', 'Категория', FilterKind.relation, relation: _catRel),
    FilterDef('curator', 'Куратор', FilterKind.relation,
        relation: RelationDef('instructors', sort: 'full_name')),
    FilterDef('from', 'Начало с', FilterKind.dateFrom, field: 'starts_at'),
    FilterDef('to', 'Начало по', FilterKind.dateTo, field: 'starts_at'),
  ],
);

final EntityDef lessonsDef = EntityDef(
  collection: 'lessons',
  path: '/lessons',
  singular: 'занятие',
  plural: 'Занятия вождением',
  accusative: 'занятие',
  icon: Icons.event_note_outlined,
  description: 'Расписание вождения: курсант, инструктор, автомобиль, время',
  defaultSort: 'starts_at',
  defaultAscending: false,
  expand: 'cadet,instructor,car',
  searchFields: const ['cadet.full_name', 'instructor.full_name', 'car.plate'],
  titleOf: (r) {
    final d = r.dateTime('starts_at');
    return '${d == null ? '' : fmtDateTime(d)} · ${_name(r.one('cadet'))}';
  },
  subtitleOf: (r) => _lbl(lessonStatuses, r.str('status')),
  beforeSave: validateLessonBeforeSave,
  actions: lessonActions,
  fields: const [
    FieldDef('cadet', 'Курсант', FieldType.relation,
        required: true,
        relation: RelationDef('cadets',
            filter: Eq('status', 'studying'), sort: 'full_name')),
    FieldDef('instructor', 'Инструктор', FieldType.relation,
        required: true,
        selfInstructor: true,
        relation: RelationDef('instructors', sort: 'full_name')),
    FieldDef('car', 'Автомобиль', FieldType.relation,
        required: true,
        relation:
            RelationDef('cars', filter: Eq('status', 'active'), sort: 'plate')),
    FieldDef('starts_at', 'Начало', FieldType.dateTime, required: true),
    FieldDef('ends_at', 'Окончание', FieldType.dateTime,
        required: true, hint: 'От 30 минут до 3 часов'),
    FieldDef('kind', 'Тип занятия', FieldType.select,
        required: true, options: lessonKinds, initial: 'city'),
    FieldDef('status', 'Статус', FieldType.select,
        required: true, options: lessonStatuses, initial: 'planned'),
    FieldDef('rating', 'Оценка (1–5)', FieldType.integer, min: 1, max: 5),
    FieldDef('notes', 'Заметки', FieldType.multiline, max: 500),
  ],
  columns: [
    ColumnDef('Начало', (r) {
      final d = r.dateTime('starts_at');
      return d == null ? '' : fmtDateTime(d);
    }, sortField: 'starts_at'),
    ColumnDef('Длительность', (r) {
      final s = r.date('starts_at'), e = r.date('ends_at');
      return s == null || e == null ? '' : '${e.difference(s).inMinutes} мин';
    }),
    ColumnDef('Курсант', (r) => _name(r.one('cadet')),
        sortField: 'cadet.full_name'),
    ColumnDef('Инструктор', (r) => _name(r.one('instructor')),
        sortField: 'instructor.full_name'),
    ColumnDef('Автомобиль', (r) => r.one('car')?.str('plate') ?? '',
        sortField: 'car.plate'),
    ColumnDef('Тип', (r) => _lbl(lessonKinds, r.str('kind'))),
    ColumnDef('Статус', (r) => _lbl(lessonStatuses, r.str('status')),
        sortField: 'status'),
  ],
  filters: const [
    FilterDef('status', 'Статус', FilterKind.select, options: lessonStatuses),
    FilterDef('kind', 'Тип', FilterKind.select, options: lessonKinds),
    FilterDef('instructor', 'Инструктор', FilterKind.relation,
        relation: RelationDef('instructors', sort: 'full_name')),
    FilterDef('car', 'Автомобиль', FilterKind.relation,
        relation: RelationDef('cars', sort: 'plate')),
    FilterDef('from', 'С даты', FilterKind.dateFrom,
        field: 'starts_at', dateTime: true),
    FilterDef('to', 'По дату', FilterKind.dateTo,
        field: 'starts_at', dateTime: true),
  ],
);

final EntityDef examsDef = EntityDef(
  collection: 'exams',
  path: '/exams',
  singular: 'экзамен',
  plural: 'Экзамены',
  accusative: 'экзамен',
  icon: Icons.fact_check_outlined,
  description: 'Внутренние экзамены: теория, площадка, город',
  defaultSort: 'exam_date',
  defaultAscending: false,
  expand: 'cadet',
  searchFields: const ['cadet.full_name', 'examiner'],
  titleOf: (r) =>
      '${_lbl(examTypes, r.str('type'))} · ${_name(r.one('cadet'))}',
  subtitleOf: (r) => _lbl(examResults, r.str('result')),
  fields: const [
    FieldDef('cadet', 'Курсант', FieldType.relation,
        required: true, relation: RelationDef('cadets', sort: 'full_name')),
    FieldDef('type', 'Вид экзамена', FieldType.select,
        required: true, options: examTypes),
    FieldDef('exam_date', 'Дата', FieldType.date, required: true),
    FieldDef('result', 'Результат', FieldType.select,
        required: true, options: examResults, initial: 'scheduled'),
    FieldDef('score', 'Баллы (0–100)', FieldType.integer, min: 0, max: 100),
    FieldDef('attempt', 'Попытка', FieldType.integer,
        required: true, min: 1, max: 20, initial: '1'),
    FieldDef('examiner', 'Экзаменатор', FieldType.text, max: 100),
  ],
  columns: [
    ColumnDef('Дата', (r) {
      final d = r.date('exam_date');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'exam_date'),
    ColumnDef('Курсант', (r) => _name(r.one('cadet')),
        sortField: 'cadet.full_name'),
    ColumnDef('Вид', (r) => _lbl(examTypes, r.str('type')), sortField: 'type'),
    ColumnDef('Результат', (r) => _lbl(examResults, r.str('result')),
        sortField: 'result'),
    ColumnDef(
        'Баллы', (r) => r['score'] == null ? '—' : '${r.integer('score')}',
        numeric: true, sortField: 'score'),
    ColumnDef('Попытка', (r) => '${r.integer('attempt')}', numeric: true),
  ],
  filters: const [
    FilterDef('type', 'Вид', FilterKind.select, options: examTypes),
    FilterDef('result', 'Результат', FilterKind.select, options: examResults),
    FilterDef('from', 'С даты', FilterKind.dateFrom, field: 'exam_date'),
    FilterDef('to', 'По дату', FilterKind.dateTo, field: 'exam_date'),
  ],
);

final EntityDef paymentsDef = EntityDef(
  collection: 'payments',
  path: '/payments',
  singular: 'платёж',
  plural: 'Платежи',
  accusative: 'платёж',
  cadetLabel: 'Мои платежи',
  icon: Icons.payments_outlined,
  description: 'Оплата обучения, пересдач и дополнительных занятий',
  defaultSort: 'paid_at',
  defaultAscending: false,
  expand: 'cadet',
  searchFields: const ['cadet.full_name', 'comment'],
  titleOf: (r) => '${fmtMoney(r.integer('amount'))} · ${_name(r.one('cadet'))}',
  subtitleOf: (r) => _lbl(payPurposes, r.str('purpose')),
  fields: const [
    FieldDef('cadet', 'Курсант', FieldType.relation,
        required: true, relation: RelationDef('cadets', sort: 'full_name')),
    FieldDef('amount', 'Сумма, ₽', FieldType.money,
        required: true, min: 1, max: 1000000),
    FieldDef('paid_at', 'Дата оплаты', FieldType.date,
        required: true, noFuture: true),
    FieldDef('method', 'Способ оплаты', FieldType.select,
        required: true, options: payMethods),
    FieldDef('purpose', 'Назначение', FieldType.select,
        required: true, options: payPurposes, initial: 'tuition'),
    FieldDef('comment', 'Комментарий', FieldType.multiline, max: 300),
  ],
  columns: [
    ColumnDef('Дата', (r) {
      final d = r.date('paid_at');
      return d == null ? '' : fmtDate(d);
    }, sortField: 'paid_at'),
    ColumnDef('Курсант', (r) => _name(r.one('cadet')),
        sortField: 'cadet.full_name'),
    ColumnDef('Сумма', (r) => fmtMoney(r.integer('amount')),
        sortField: 'amount', numeric: true),
    ColumnDef('Способ', (r) => _lbl(payMethods, r.str('method')),
        sortField: 'method'),
    ColumnDef('Назначение', (r) => _lbl(payPurposes, r.str('purpose')),
        sortField: 'purpose'),
  ],
  filters: const [
    FilterDef('method', 'Способ', FilterKind.select, options: payMethods),
    FilterDef('purpose', 'Назначение', FilterKind.select, options: payPurposes),
    FilterDef('from', 'С даты', FilterKind.dateFrom, field: 'paid_at'),
    FilterDef('to', 'По дату', FilterKind.dateTo, field: 'paid_at'),
  ],
);

final EntityDef usersDef = EntityDef(
  collection: 'users',
  path: '/users',
  singular: 'пользователь',
  plural: 'Пользователи',
  accusative: 'пользователя',
  icon: Icons.manage_accounts_outlined,
  description: 'Учётные записи и роли',
  defaultSort: 'created',
  defaultAscending: false,
  softDelete: false,
  searchFields: const ['email', 'name'],
  titleOf: (r) => r.str('name').isEmpty ? r.str('email') : r.str('name'),
  subtitleOf: (r) => r.str('email'),
  fields: const [
    FieldDef('email', 'Электронная почта', FieldType.email, required: true),
    FieldDef('name', 'Имя', FieldType.text, required: true, min: 2, max: 100),
    FieldDef('role', 'Роль', FieldType.select,
        required: true, options: userRoles, initial: 'instructor'),
    FieldDef('password', 'Пароль', FieldType.password,
        required: true,
        createOnly: true,
        min: 8,
        max: 72,
        hint: 'Не короче 8 символов'),
    FieldDef('passwordConfirm', 'Повторите пароль', FieldType.password,
        required: true, createOnly: true, sameAs: 'password'),
  ],
  columns: [
    ColumnDef('Почта', (r) => r.str('email'), sortField: 'email'),
    ColumnDef('Имя', (r) => r.str('name'), sortField: 'name'),
    ColumnDef('Роль', (r) => _lbl(userRoles, r.str('role')), sortField: 'role'),
  ],
  filters: const [
    FilterDef('role', 'Роль', FilterKind.select, options: userRoles),
  ],
);

final Map<String, EntityDef> entityDefs = {
  for (final d in [
    categoriesDef,
    cadetsDef,
    medicalDef,
    instructorsDef,
    carsDef,
    groupsDef,
    lessonsDef,
    examsDef,
    paymentsDef,
    usersDef,
  ])
    d.collection: d,
};

Map<String, Map<String, String>> relationMap() => {
      for (final d in entityDefs.values)
        d.collection: {
          for (final f in d.fields)
            if (f.relation != null) f.name: f.relation!.collection,
        },
    };

EntityDef? entityForPath(String path) {
  for (final d in entityDefs.values) {
    if (d.path == path) return d;
  }
  return null;
}
