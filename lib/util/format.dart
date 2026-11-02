library;

String two(int n) => n.toString().padLeft(2, '0');

String fmtDate(DateTime d) => '${two(d.day)}.${two(d.month)}.${d.year}';

String fmtTime(DateTime d) => '${two(d.hour)}:${two(d.minute)}';

String fmtDateTime(DateTime d) => '${fmtDate(d)} ${fmtTime(d)}';

String fmtMoney(num value) {
  final s = value.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) buf.write(' ');
    buf.write(s[i]);
  }
  return '${value < 0 ? '-' : ''}$buf ₽';
}

DateTime? parsePbDate(Object? value) {
  if (value is! String || value.isEmpty) return null;
  return DateTime.tryParse(value.replaceFirst(' ', 'T'));
}

String toPbDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-'
    '${two(d.month)}-${two(d.day)} 00:00:00.000Z';

String toPbDateTime(DateTime local) {
  final u = local.toUtc();
  return '${u.year.toString().padLeft(4, '0')}-${two(u.month)}-${two(u.day)} '
      '${two(u.hour)}:${two(u.minute)}:${two(u.second)}.000Z';
}

String plural(int n, String one, String few, String many) {
  final m10 = n.abs() % 10, m100 = n.abs() % 100;
  if (m10 == 1 && m100 != 11) return one;
  if (m10 >= 2 && m10 <= 4 && (m100 < 12 || m100 > 14)) return few;
  return many;
}

DateTime dayStart(DateTime d) => DateTime(d.year, d.month, d.day);

DateTime weekStart(DateTime d) =>
    dayStart(d).subtract(Duration(days: d.weekday - 1));

const weekdayShort = ['Пн', 'Вт', 'Ср', 'Чт', 'Пт', 'Сб', 'Вс'];
const weekdayFull = [
  'Понедельник',
  'Вторник',
  'Среда',
  'Четверг',
  'Пятница',
  'Суббота',
  'Воскресенье'
];
const monthNames = [
  'январь',
  'февраль',
  'март',
  'апрель',
  'май',
  'июнь',
  'июль',
  'август',
  'сентябрь',
  'октябрь',
  'ноябрь',
  'декабрь'
];
