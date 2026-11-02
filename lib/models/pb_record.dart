import '../util/format.dart';

class PbRecord {
  const PbRecord(this.data, [this.expand = const {}]);

  final Map<String, dynamic> data;

  final Map<String, List<PbRecord>> expand;

  factory PbRecord.fromJson(Map<String, dynamic> json) {
    final expandRaw = json['expand'];
    final expand = <String, List<PbRecord>>{};
    if (expandRaw is Map) {
      expandRaw.forEach((key, value) {
        if (value is Map) {
          expand['$key'] = [
            PbRecord.fromJson(Map<String, dynamic>.from(value))
          ];
        } else if (value is List) {
          expand['$key'] = [
            for (final v in value)
              if (v is Map) PbRecord.fromJson(Map<String, dynamic>.from(v)),
          ];
        }
      });
    }
    final data = Map<String, dynamic>.from(json)..remove('expand');
    return PbRecord(data, expand);
  }

  String get id => str('id');

  bool get deleted => flag('deleted');

  Object? operator [](String field) => data[field];

  String str(String field) {
    final v = data[field];
    if (v == null) return '';
    return v is String ? v : '$v';
  }

  int integer(String field, [int fallback = 0]) {
    final v = data[field];
    if (v is num) return v.toInt();
    if (v is String) return int.tryParse(v) ?? fallback;
    return fallback;
  }

  bool flag(String field) => data[field] == true;

  List<String> ids(String field) {
    final v = data[field];
    if (v is List) return [for (final x in v) '$x'];
    if (v is String && v.isNotEmpty) return [v];
    return const [];
  }

  String rel(String field) => str(field);

  DateTime? date(String field) => parsePbDate(data[field]);

  DateTime? dateTime(String field) => date(field)?.toLocal();

  PbRecord? one(String field) {
    final list = expand[field];
    return list == null || list.isEmpty ? null : list.first;
  }

  List<PbRecord> many(String field) => expand[field] ?? const [];

  PbRecord copyWith(Map<String, dynamic> changes) =>
      PbRecord({...data, ...changes}, expand);
}
