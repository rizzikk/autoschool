import '../models/page_result.dart';
import '../models/pb_record.dart';
import 'conditions.dart';

class BusySlot {
  const BusySlot({
    required this.id,
    required this.start,
    required this.end,
    this.instructor = '',
    this.car = '',
    this.cadet = '',
  });

  final String id;
  final DateTime start;
  final DateTime end;
  final String instructor;
  final String car;
  final String cadet;

  bool overlaps(DateTime from, DateTime to) =>
      start.isBefore(to) && end.isAfter(from);
}

abstract class RecordRepository {
  Future<PageResult<PbRecord>> list(
    String collection, {
    int page = 1,
    int perPage = 10,
    Cond? where,
    String? sort,
    String? expand,
  });

  Future<List<PbRecord>> listAll(
    String collection, {
    Cond? where,
    String? sort,
    String? expand,
  });

  Future<PbRecord?> find(String collection, String id, {String? expand});

  Future<PbRecord> create(String collection, Map<String, dynamic> body);

  Future<PbRecord> update(
      String collection, String id, Map<String, dynamic> body);

  Future<void> delete(String collection, String id);

  Future<List<BusySlot>> busy({
    required DateTime from,
    required DateTime to,
    String? instructor,
    String? car,
    String? cadet,
  });
}
