import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:autoschool_client/models/page_result.dart';
import 'package:autoschool_client/models/pb_record.dart';
import 'package:autoschool_client/repositories/conditions.dart';
import 'package:autoschool_client/repositories/record_repository.dart';

class FlakyRepository implements RecordRepository {
  FlakyRepository(this.inner);

  final RecordRepository inner;
  bool down = false;
  int calls = 0;

  T _check<T>(T Function() action) {
    calls++;
    if (down) throw const NetworkException();
    return action();
  }

  @override
  Future<PageResult<PbRecord>> list(String collection,
          {int page = 1,
          int perPage = 10,
          Cond? where,
          String? sort,
          String? expand}) async =>
      _check(() => inner.list(collection,
          page: page,
          perPage: perPage,
          where: where,
          sort: sort,
          expand: expand));

  @override
  Future<List<PbRecord>> listAll(String collection,
          {Cond? where, String? sort, String? expand}) async =>
      _check(() =>
          inner.listAll(collection, where: where, sort: sort, expand: expand));

  @override
  Future<PbRecord?> find(String collection, String id,
          {String? expand}) async =>
      _check(() => inner.find(collection, id, expand: expand));

  @override
  Future<PbRecord> create(String collection, Map<String, dynamic> body) async =>
      _check(() => inner.create(collection, body));

  @override
  Future<PbRecord> update(
          String collection, String id, Map<String, dynamic> body) async =>
      _check(() => inner.update(collection, id, body));

  @override
  Future<void> delete(String collection, String id) async =>
      _check(() => inner.delete(collection, id));

  @override
  Future<List<BusySlot>> busy({
    required DateTime from,
    required DateTime to,
    String? instructor,
    String? car,
    String? cadet,
  }) async =>
      _check(() => inner.busy(
          from: from, to: to, instructor: instructor, car: car, cadet: cadet));
}
