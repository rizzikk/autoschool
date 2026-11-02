import '../forms/validators.dart';
import '../models/pb_record.dart';
import '../util/format.dart';
import 'entities.dart';
import 'entity_def.dart';

bool isEmptyValue(Object? v) =>
    v == null || (v is String && v.trim().isEmpty) || (v is List && v.isEmpty);

String _chars(int n) => plural(n, 'символа', 'символов', 'символов');

String? validateField(FieldDef f, Object? value, {Object? other}) {
  if (isEmptyValue(value)) {
    if (!f.required && f.minItems == 0) return null;
    return switch (f.type) {
      FieldType.select || FieldType.relation => f.multi
          ? 'Выберите хотя бы одно значение'
          : 'Выберите значение из списка',
      FieldType.date => 'Укажите дату',
      FieldType.dateTime => 'Укажите дату и время',
      _ => 'Обязательное поле',
    };
  }
  switch (f.type) {
    case FieldType.text:
    case FieldType.multiline:
    case FieldType.password:
    case FieldType.email:
    case FieldType.phone:
      final text = '$value'.trim();
      if (f.type == FieldType.email) {
        final e = Validators.email()(text);
        if (e != null) return e;
      }
      final min = f.min?.toInt();
      final max = f.max?.toInt();
      if (min != null && text.length < min) {
        return 'Не короче $min ${_chars(min)}';
      }
      if (max != null && text.length > max) {
        return 'Не длиннее $max ${_chars(max)}';
      }
      if (f.pattern != null && !RegExp(f.pattern!).hasMatch(text)) {
        return f.patternMessage ?? 'Неверный формат';
      }
      if (f.sameAs != null && other != null && '$other' != '$value') {
        return 'Значения не совпадают';
      }
    case FieldType.integer:
    case FieldType.money:
      final n = int.tryParse('$value'.trim());
      if (n == null) return 'Введите целое число';
      if (f.min != null && n < f.min!) return 'Не меньше ${f.min!.toInt()}';
      if (f.max != null && n > f.max!) return 'Не больше ${f.max!.toInt()}';
    case FieldType.date:
    case FieldType.dateTime:
      if (value is! DateTime) return 'Некорректная дата';
      if (f.noFuture && value.isAfter(DateTime.now())) {
        return 'Дата не может быть в будущем';
      }
    case FieldType.relation:
      if (f.multi && value is List && value.length < f.minItems) {
        return 'Выберите хотя бы одно значение';
      }
    case FieldType.boolean:
    case FieldType.select:
      break;
  }
  return null;
}

Object? encodeField(FieldDef f, Object? value) {
  switch (f.type) {
    case FieldType.text:
    case FieldType.multiline:
    case FieldType.email:
    case FieldType.phone:
      return '${value ?? ''}'.trim();
    case FieldType.password:
      return '${value ?? ''}';
    case FieldType.integer:
    case FieldType.money:
      return int.tryParse('${value ?? ''}'.trim());
    case FieldType.boolean:
      return value == true;
    case FieldType.select:
      return '${value ?? ''}';
    case FieldType.relation:
      if (f.multi) return [for (final v in (value as List? ?? const [])) '$v'];
      return '${value ?? ''}';
    case FieldType.date:
      return value is DateTime ? toPbDate(value) : '';
    case FieldType.dateTime:
      return value is DateTime ? toPbDateTime(value) : '';
  }
}

Object? decodeField(FieldDef f, PbRecord r) {
  switch (f.type) {
    case FieldType.text:
    case FieldType.multiline:
    case FieldType.email:
    case FieldType.phone:
      return r.str(f.name);
    case FieldType.password:
      return '';
    case FieldType.integer:
    case FieldType.money:
      final raw = r[f.name];
      if (raw is! num || (raw == 0 && !f.required)) return '';
      return '${raw.toInt()}';
    case FieldType.boolean:
      return r.flag(f.name);
    case FieldType.select:
      final chosen = r.str(f.name);
      return chosen.isEmpty ? null : chosen;
    case FieldType.relation:
      if (f.multi) return r.ids(f.name);
      final linked = r.rel(f.name);
      return linked.isEmpty ? null : linked;
    case FieldType.date:
      final day = r.date(f.name);
      return day == null ? null : DateTime(day.year, day.month, day.day);
    case FieldType.dateTime:
      return r.dateTime(f.name);
  }
}

String displayField(FieldDef f, PbRecord r) {
  switch (f.type) {
    case FieldType.boolean:
      return r.flag(f.name) ? 'Да' : 'Нет';
    case FieldType.select:
      final key = r.str(f.name);
      return f.options[key] ?? key;
    case FieldType.relation:
      final target = f.relation!.collection;
      final def = entityDefs[target];
      final expanded = r.many(f.name);
      if (expanded.isEmpty) {
        return r.ids(f.name).isEmpty ? '—' : '(не показана)';
      }
      return expanded.map((e) => def?.titleOf(e) ?? e.id).join(', ');
    case FieldType.date:
      final day = r.date(f.name);
      return day == null ? '—' : fmtDate(day);
    case FieldType.dateTime:
      final moment = r.dateTime(f.name);
      return moment == null ? '—' : fmtDateTime(moment);
    case FieldType.money:
      return r[f.name] == null ? '—' : fmtMoney(r.integer(f.name));
    case FieldType.integer:
      return r[f.name] == null ? '—' : '${r.integer(f.name)}';
    case FieldType.password:
      return '••••••••';
    default:
      final text = r.str(f.name);
      return text.isEmpty ? '—' : text;
  }
}
