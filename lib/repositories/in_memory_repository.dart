import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/pb_record.dart';
import '../util/format.dart';
import 'conditions.dart';
import 'record_repository.dart';

class InMemoryRepository implements RecordRepository {
  InMemoryRepository({
    Map<String, List<Map<String, dynamic>>> data = const {},
    this.relations = const {},
    this.validator,
  }) {
    data.forEach((name, rows) {
      _tables[name] = [
        for (final r in rows) <String, dynamic>{'deleted': false, ...r},
      ];
    });
  }

  final Map<String, Map<String, String>> relations;

  final void Function(String op, String collection, Map<String, dynamic> body)?
      validator;

  final Map<String, List<Map<String, dynamic>>> _tables = {};
  int _seq = 0;

  List<Map<String, dynamic>> _table(String name) =>
      _tables.putIfAbsent(name, () => []);

  int count(String collection) => _table(collection).length;

  Object? _value(String collection, Map<String, dynamic> row, String path) {
    final parts = path.split('.');
    Object? current = row[parts.first];
    var coll = collection;
    for (var i = 1; i < parts.length; i++) {
      final target = relations[coll]?[parts[i - 1]];
      if (target == null || current is! String) return null;
      final found = _table(target).where((r) => r['id'] == current).firstOrNull;
      if (found == null) return null;
      coll = target;
      current = found[parts[i]];
    }
    return current;
  }

  bool _matches(String c, Cond? cond, Map<String, dynamic> row) {
    if (cond == null) return true;
    return switch (cond) {
      Eq(:final field, :final value) => () {
          final v = _value(c, row, field);
          return v is List ? v.contains(value) : v == value;
        }(),
      Has(:final field, :final value) => () {
          final v = _value(c, row, field);
          return v is List ? v.contains(value) : v == value;
        }(),
      Like(:final field, :final text) => '${_value(c, row, field) ?? ''}'
          .toLowerCase()
          .contains(text.toLowerCase()),
      Gte(:final field, :final value) =>
        '${_value(c, row, field) ?? ''}'.compareTo(value) >= 0,
      Lte(:final field, :final value) =>
        '${_value(c, row, field) ?? ''}'.compareTo(value) <= 0,
      And(:final items) => items.every((i) => _matches(c, i, row)),
      Or(:final items) => items.any((i) => _matches(c, i, row)),
    };
  }

  int _compare(Object? a, Object? b) {
    if (a is num && b is num) return a.compareTo(b);
    if (a is bool && b is bool) return a == b ? 0 : (a ? 1 : -1);
    return '${a ?? ''}'.toLowerCase().compareTo('${b ?? ''}'.toLowerCase());
  }

  List<Map<String, dynamic>> _select(String c, Cond? where, String? sort) {
    final rows = _table(c).where((r) => _matches(c, where, r)).toList();
    if (sort != null && sort.isNotEmpty) {
      final desc = sort.startsWith('-');
      final field = sort.replaceFirst(RegExp(r'^[-+]'), '');
      rows.sort((a, b) {
        final r = _compare(_value(c, a, field), _value(c, b, field));
        return desc ? -r : r;
      });
    }
    return rows;
  }

  PbRecord _toRecord(String c, Map<String, dynamic> row, String? expand) {
    final expanded = <String, List<PbRecord>>{};
    if (expand != null && expand.isNotEmpty) {
      for (final field in expand.split(',')) {
        final target = relations[c]?[field.trim()];
        if (target == null) continue;
        final v = row[field.trim()];
        final ids = v is List ? v : (v is String && v.isNotEmpty ? [v] : []);
        expanded[field.trim()] = [
          for (final id in ids)
            for (final r in _table(target).where((r) => r['id'] == id))
              PbRecord(Map<String, dynamic>.of(r)),
        ];
      }
    }
    return PbRecord(Map<String, dynamic>.of(row), expanded);
  }

  @override
  Future<PageResult<PbRecord>> list(
    String collection, {
    int page = 1,
    int perPage = 10,
    Cond? where,
    String? sort,
    String? expand,
  }) async {
    final rows = _select(collection, where, sort);
    final from = (page - 1) * perPage;
    final slice = from >= rows.length
        ? <Map<String, dynamic>>[]
        : rows.sublist(from, (from + perPage).clamp(0, rows.length));
    return PageResult(
      items: [for (final r in slice) _toRecord(collection, r, expand)],
      page: page,
      size: perPage,
      total: rows.length,
    );
  }

  @override
  Future<List<PbRecord>> listAll(String collection,
          {Cond? where, String? sort, String? expand}) async =>
      [
        for (final r in _select(collection, where, sort))
          _toRecord(collection, r, expand),
      ];

  @override
  Future<PbRecord?> find(String collection, String id, {String? expand}) async {
    final row = _table(collection).where((r) => r['id'] == id).firstOrNull;
    return row == null ? null : _toRecord(collection, row, expand);
  }

  @override
  Future<PbRecord> create(String collection, Map<String, dynamic> body) async {
    validator?.call('create', collection, body);
    final now = toPbDateTime(DateTime.now());
    final row = <String, dynamic>{
      'deleted': false,
      ...body,
      'id': 'm${(++_seq).toString().padLeft(4, '0')}',
      'created': now,
      'updated': now,
    };
    _table(collection).add(row);
    return PbRecord(Map<String, dynamic>.of(row));
  }

  @override
  Future<PbRecord> update(
      String collection, String id, Map<String, dynamic> body) async {
    final row = _table(collection).where((r) => r['id'] == id).firstOrNull;
    if (row == null) throw const NotFoundException();
    validator?.call('update', collection, body);
    row
      ..addAll(body)
      ..['updated'] = toPbDateTime(DateTime.now());
    return PbRecord(Map<String, dynamic>.of(row));
  }

  @override
  Future<void> delete(String collection, String id) async {
    final table = _table(collection);
    final index = table.indexWhere((r) => r['id'] == id);
    if (index < 0) throw const NotFoundException();
    for (final entry in relations.entries) {
      for (final field in entry.value.entries) {
        if (field.value != collection) continue;
        final referenced = _table(entry.key).any((r) {
          final v = r[field.key];
          return v is List ? v.contains(id) : v == id;
        });
        if (referenced) {
          throw const ConflictException(
              'Запись нельзя удалить: на неё ссылаются другие записи.');
        }
      }
    }
    table.removeAt(index);
  }

  @override
  Future<List<BusySlot>> busy({
    required DateTime from,
    required DateTime to,
    String? instructor,
    String? car,
    String? cadet,
  }) async {
    final result = <BusySlot>[];
    for (final r in _table('lessons')) {
      if (r['deleted'] == true || r['status'] == 'cancelled') continue;
      final start = parsePbDate(r['starts_at']);
      final end = parsePbDate(r['ends_at']);
      if (start == null || end == null) continue;
      final mine = (instructor != null && r['instructor'] == instructor) ||
          (car != null && r['car'] == car) ||
          (cadet != null && r['cadet'] == cadet);
      if (!mine || !start.isBefore(to.toUtc()) || !end.isAfter(from.toUtc())) {
        continue;
      }
      result.add(BusySlot(
        id: '${r['id']}',
        start: start,
        end: end,
        instructor: '${r['instructor']}',
        car: '${r['car']}',
        cadet: '${r['cadet']}',
      ));
    }
    return result;
  }
}
