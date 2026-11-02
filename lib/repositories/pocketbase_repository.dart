import 'package:dio/dio.dart';

import '../core/api_exceptions.dart';
import '../models/page_result.dart';
import '../models/pb_record.dart';
import '../util/format.dart';
import 'conditions.dart';
import 'pb_filter.dart';
import 'record_repository.dart';

class PocketBaseRepository implements RecordRepository {
  PocketBaseRepository(this._dio);

  final Dio _dio;

  String _path(String collection, [String? id]) =>
      '/collections/$collection/records${id == null ? '' : '/$id'}';

  Map<String, dynamic> _asMap(dynamic data) {
    if (data is Map) return Map<String, dynamic>.from(data);
    throw const ServerException('Сервер вернул неожиданный ответ.');
  }

  PbRecord _record(dynamic data) => PbRecord.fromJson(_asMap(data));

  @override
  Future<PageResult<PbRecord>> list(
    String collection, {
    int page = 1,
    int perPage = 10,
    Cond? where,
    String? sort,
    String? expand,
  }) =>
      guard(() async {
        final filter = toPbFilter(where);
        final response =
            await _dio.get<dynamic>(_path(collection), queryParameters: {
          'page': page,
          'perPage': perPage,
          if (filter.isNotEmpty) 'filter': filter,
          if (sort != null && sort.isNotEmpty) 'sort': sort,
          if (expand != null && expand.isNotEmpty) 'expand': expand,
        });
        final body = _asMap(response.data);
        final items = body['items'];
        return PageResult<PbRecord>(
          items: [
            if (items is List)
              for (final i in items)
                if (i is Map) PbRecord.fromJson(Map<String, dynamic>.from(i)),
          ],
          page: (body['page'] as num?)?.toInt() ?? page,
          size: (body['perPage'] as num?)?.toInt() ?? perPage,
          total: (body['totalItems'] as num?)?.toInt() ?? 0,
        );
      });

  @override
  Future<List<PbRecord>> listAll(
    String collection, {
    Cond? where,
    String? sort,
    String? expand,
  }) async {
    const pageSize = 200;
    final all = <PbRecord>[];
    for (var page = 1; page <= 50; page++) {
      final result = await list(collection,
          page: page,
          perPage: pageSize,
          where: where,
          sort: sort,
          expand: expand);
      all.addAll(result.items);
      if (!result.hasNext) break;
    }
    return all;
  }

  @override
  Future<PbRecord?> find(String collection, String id, {String? expand}) async {
    try {
      return await guard(() async {
        final response =
            await _dio.get<dynamic>(_path(collection, id), queryParameters: {
          if (expand != null && expand.isNotEmpty) 'expand': expand,
        });
        return _record(response.data);
      });
    } on NotFoundException {
      return null;
    }
  }

  @override
  Future<PbRecord> create(String collection, Map<String, dynamic> body) =>
      guard(() async {
        final response =
            await _dio.post<dynamic>(_path(collection), data: body);
        return _record(response.data);
      });

  @override
  Future<PbRecord> update(
          String collection, String id, Map<String, dynamic> body) =>
      guard(() async {
        final response =
            await _dio.patch<dynamic>(_path(collection, id), data: body);
        return _record(response.data);
      });

  @override
  Future<void> delete(String collection, String id) => guard(() async {
        await _dio.delete<dynamic>(_path(collection, id));
      });

  @override
  Future<List<BusySlot>> busy({
    required DateTime from,
    required DateTime to,
    String? instructor,
    String? car,
    String? cadet,
  }) =>
      guard(() async {
        final response =
            await _dio.get<dynamic>('/autoschool/busy', queryParameters: {
          'from': toPbDateTime(from),
          'to': toPbDateTime(to),
          if (instructor != null && instructor.isNotEmpty)
            'instructor': instructor,
          if (car != null && car.isNotEmpty) 'car': car,
          if (cadet != null && cadet.isNotEmpty) 'cadet': cadet,
        });
        final items = _asMap(response.data)['items'];
        return [
          if (items is List)
            for (final i in items)
              if (i is Map)
                BusySlot(
                  id: '${i['id'] ?? ''}',
                  start: parsePbDate(i['starts_at']) ?? from,
                  end: parsePbDate(i['ends_at']) ?? to,
                  instructor: '${i['instructor'] ?? ''}',
                  car: '${i['car'] ?? ''}',
                  cadet: '${i['cadet'] ?? ''}',
                ),
        ];
      });
}
