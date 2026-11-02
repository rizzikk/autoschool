library;

typedef Validator = String? Function(String? value);

abstract final class Validators {
  static Validator required([String message = 'Обязательное поле']) =>
      (v) => (v == null || v.trim().isEmpty) ? message : null;

  static Validator length({int min = 0, required int max}) => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        if (t.length < min) return 'Не короче $min ${_chars(min)}';
        if (t.length > max) return 'Не длиннее $max ${_chars(max)}';
        return null;
      };

  static Validator intRange(int min, int max) => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        final n = int.tryParse(t);
        if (n == null) return 'Введите целое число';
        if (n < min || n > max) return 'Допустимо от $min до $max';
        return null;
      };

  static Validator positive({int max = 1000000}) => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        final n = int.tryParse(t);
        if (n == null) return 'Введите целое число';
        if (n <= 0) return 'Должно быть больше нуля';
        if (n > max) return 'Не больше $max';
        return null;
      };

  static Validator email() => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        return _email.hasMatch(t)
            ? null
            : 'Неверный формат почты: name@example.ru';
      };

  static Validator isbn() => (v) {
        final t = (v ?? '').replaceAll(RegExp(r'[\s-]'), '').toUpperCase();
        if (t.isEmpty) return null;
        final ok10 = RegExp(r'^\d{9}[\dX]$').hasMatch(t);
        final ok13 = RegExp(r'^97[89]\d{10}$').hasMatch(t);
        return ok10 || ok13
            ? null
            : 'ISBN — 10 или 13 цифр (13-значный начинается с 978 или 979)';
      };

  static Validator phone() => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        if (!RegExp(r'^\+?[\d\s()-]+$').hasMatch(t)) {
          return 'Только цифры, +, пробелы, скобки и дефисы';
        }
        final digits = t.replaceAll(RegExp(r'\D'), '').length;
        return digits >= 10 && digits <= 15 ? null : 'От 10 до 15 цифр';
      };

  static Validator letters() => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        return RegExp(r"^[A-Za-zА-Яа-яЁё\s'.-]+$").hasMatch(t)
            ? null
            : 'Допустимы только буквы, пробел и дефис';
      };

  static Validator cardNumber() => (v) {
        final t = (v ?? '').trim().toUpperCase();
        if (t.isEmpty) return null;
        return RegExp(r'^[A-ZА-ЯЁ]{2}-\d{6}$').hasMatch(t)
            ? null
            : 'Формат: две буквы, дефис, шесть цифр (ЧБ-000123)';
      };

  static Validator date({DateTime? notBefore, DateTime? notAfter}) => (v) {
        final t = (v ?? '').trim();
        if (t.isEmpty) return null;
        final d = parseDate(t);
        if (d == null) return 'Дата в формате дд.мм.гггг';
        if (notBefore != null && d.isBefore(notBefore)) {
          return 'Не раньше ${formatDate(notBefore)}';
        }
        if (notAfter != null && d.isAfter(notAfter)) {
          return 'Не позже ${formatDate(notAfter)}';
        }
        return null;
      };

  static Validator check(String? Function(String value) test) => (v) {
        final t = (v ?? '').trim();
        return t.isEmpty ? null : test(t);
      };

  static Validator all(List<Validator> validators) => (v) {
        for (final validate in validators) {
          final error = validate(v);
          if (error != null) return error;
        }
        return null;
      };

  static final _email = RegExp(r'^[\w.+-]+@[\w-]+(\.[\w-]+)*\.[A-Za-z]{2,}$');

  static String _chars(int n) {
    final mod10 = n % 10, mod100 = n % 100;
    if (mod10 == 1 && mod100 != 11) return 'символа';
    return 'символов';
  }
}

int? parseIntOrNull(String text) => int.tryParse(text.trim());

DateTime? parseDate(String text) {
  final m = RegExp(r'^(\d{1,2})\.(\d{1,2})\.(\d{4})$').firstMatch(text.trim());
  if (m == null) return null;
  final day = int.parse(m.group(1)!);
  final month = int.parse(m.group(2)!);
  final year = int.parse(m.group(3)!);
  final d = DateTime(year, month, day);
  return d.day == day && d.month == month && d.year == year ? d : null;
}

String formatDate(DateTime d) =>
    '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
