import 'package:autoschool_client/core/api_client.dart';
import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:autoschool_client/core/connection.dart';
import 'package:autoschool_client/core/session.dart';
import 'package:autoschool_client/repositories/conditions.dart';
import 'package:autoschool_client/repositories/pocketbase_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/fake_adapter.dart';

Dio makeDio(FakeAdapter adapter,
    {ApiSession? session, ConnectionNotifier? connection}) {
  final dio = buildDio(session ?? ApiSession(),
      baseUrl: 'http://test/api',
      retryDelay: const Duration(milliseconds: 1),
      log: (_) {},
      connection: connection);
  dio.httpClientAdapter = adapter;
  return dio;
}

Map<String, dynamic> page(List<Map<String, dynamic>> items, {int total = -1}) =>
    {
      'page': 1,
      'perPage': 10,
      'totalItems': total < 0 ? items.length : total,
      'totalPages': 1,
      'items': items,
    };

void main() {
  group('PocketBaseRepository: запросы к REST API', () {
    test(
        'список: фильтр, сортировка, раскрытие связей и страница уходят параметрами',
        () async {
      final adapter = FakeAdapter((o) => jsonBody(
          200,
          page([
            {'id': 'k1', 'full_name': 'Иванова', 'deleted': false}
          ], total: 41)));
      final repo = PocketBaseRepository(makeDio(adapter));

      final result = await repo.list('cadets',
          page: 3,
          perPage: 25,
          where: const And([Eq('deleted', false), Eq('status', 'studying')]),
          sort: '-full_name',
          expand: 'category');

      final q = adapter.requests.single.uri.queryParameters;
      expect(adapter.log, ['GET /api/collections/cadets/records']);
      expect(q['page'], '3');
      expect(q['perPage'], '25');
      expect(q['sort'], '-full_name');
      expect(q['expand'], 'category');
      expect(q['filter'], "(deleted = false && status = 'studying')");
      expect(result.total, 41);
      expect(result.items.single.id, 'k1');
    });

    test('токен уходит в заголовке Authorization без слова Bearer', () async {
      final adapter = FakeAdapter((o) => jsonBody(200, page([])));
      final session = ApiSession()..accessToken = 'abc.def.ghi';
      await PocketBaseRepository(makeDio(adapter, session: session))
          .list('cars');
      expect(adapter.requests.single.headers['Authorization'], 'abc.def.ghi');
    });

    test('создание: POST с телом, ответ превращается в запись', () async {
      final adapter =
          FakeAdapter((o) => jsonBody(200, {'id': 'c9', 'plate': 'А123ВС77'}));
      final created = await PocketBaseRepository(makeDio(adapter))
          .create('cars', {'plate': 'А123ВС77'});
      expect(adapter.log, ['POST /api/collections/cars/records']);
      expect(adapter.requests.single.data, {'plate': 'А123ВС77'});
      expect(created.id, 'c9');
    });

    test('мягкое удаление — PATCH с deleted=true', () async {
      final adapter = FakeAdapter((o) => jsonBody(200, {'id': 'k1'}));
      await PocketBaseRepository(makeDio(adapter))
          .update('cadets', 'k1', {'deleted': true});
      expect(adapter.log, ['PATCH /api/collections/cadets/records/k1']);
      expect(adapter.requests.single.data, {'deleted': true});
    });

    test('find: 404 даёт null, а не исключение', () async {
      final adapter = FakeAdapter((o) => jsonBody(404, {'message': 'нет'}));
      expect(await PocketBaseRepository(makeDio(adapter)).find('cars', 'x'),
          isNull);
    });
  });

  group('PocketBaseRepository: ошибки сети и сервера', () {
    test('400 с полями → ValidationException с ошибками под полями', () async {
      final adapter = FakeAdapter((o) => jsonBody(400, {
            'message': 'Failed to create record.',
            'data': {
              'plate': {'code': 'validation_invalid_format', 'message': 'x'}
            }
          }));
      await expectLater(
        PocketBaseRepository(makeDio(adapter)).create('cars', {'plate': 'x'}),
        throwsA(isA<ValidationException>().having(
            (e) => e.errors['plate'], 'plate', 'Неверный формат значения')),
      );
    });

    test('409 → ConflictException', () async {
      final adapter = FakeAdapter((o) => jsonBody(409, {
            'message': 'Инструктор в это время занят другим занятием.',
            'data': {
              'instructor': {'code': 'busy', 'message': 'Инструктор занят.'}
            }
          }));
      await expectLater(
        PocketBaseRepository(makeDio(adapter)).create('lessons', {}),
        throwsA(isA<ConflictException>()),
      );
    });

    test('403 → ForbiddenException', () async {
      final adapter = FakeAdapter((o) => jsonBody(403, {'message': 'no'}));
      await expectLater(
          PocketBaseRepository(makeDio(adapter)).create('cars', {}),
          throwsA(isA<ForbiddenException>()));
    });

    test('500 → ServerException', () async {
      final adapter = FakeAdapter((o) => jsonBody(500, {'message': 'boom'}));
      await expectLater(PocketBaseRepository(makeDio(adapter)).list('cars'),
          throwsA(isA<ServerException>()));
    });

    test(
        'сервер остановлен: чтение повторяется три раза, затем NetworkException',
        () async {
      final connection = ConnectionNotifier();
      final adapter = FakeAdapter((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'сервер остановлен'));
      await expectLater(
        PocketBaseRepository(makeDio(adapter, connection: connection))
            .list('cars'),
        throwsA(isA<NetworkException>()),
      );
      expect(adapter.requests.length, 3,
          reason: 'исходный запрос и два повтора');
      expect(connection.offline, isTrue);
      connection.dispose();
    });

    test('запись при сетевом сбое не повторяется: иначе создалась бы дважды',
        () async {
      final adapter = FakeAdapter((o) => throw DioException.connectionError(
          requestOptions: o, reason: 'сервер остановлен'));
      await expectLater(
        PocketBaseRepository(makeDio(adapter)).create('cars', {'plate': 'x'}),
        throwsA(isA<NetworkException>()),
      );
      expect(adapter.requests.length, 1);
    });

    test('таймаут → NetworkException', () async {
      final adapter = FakeAdapter((o) => throw DioException.receiveTimeout(
          timeout: const Duration(seconds: 15), requestOptions: o));
      await expectLater(
          PocketBaseRepository(makeDio(adapter)).create('cars', {}),
          throwsA(isA<NetworkException>()));
    });
  });

  group('токен', () {
    test('401: токен обновляется, исходный запрос повторяется один раз',
        () async {
      final session = ApiSession()..accessToken = 'old';
      session.refresh = () async {
        session.accessToken = 'new';
        return true;
      };
      final adapter = FakeAdapter((o) {
        final ok = o.headers['Authorization'] == 'new';
        return ok
            ? jsonBody(
                200,
                page([
                  {'id': 'c1'}
                ]))
            : jsonBody(401, {'message': 'expired'});
      });
      final result =
          await PocketBaseRepository(makeDio(adapter, session: session))
              .list('cars');
      expect(result.items.single.id, 'c1');
      expect(adapter.requests.length, 2);
      expect(adapter.requests.last.headers['Authorization'], 'new');
    });

    test('401 и обновить токен не удалось → UnauthorizedException, без цикла',
        () async {
      final session = ApiSession()..accessToken = 'old';
      var refreshCalls = 0;
      session.refresh = () async {
        refreshCalls++;
        return false;
      };
      final adapter = FakeAdapter((o) => jsonBody(401, {'message': 'expired'}));
      await expectLater(
        PocketBaseRepository(makeDio(adapter, session: session)).list('cars'),
        throwsA(isA<UnauthorizedException>()),
      );
      expect(refreshCalls, 1);
      expect(adapter.requests.length, 1);
    });
  });

  group('занятость', () {
    test('busy читает интервалы и передаёт участников параметрами', () async {
      final adapter = FakeAdapter((o) => jsonBody(200, {
            'items': [
              {
                'id': 'l1',
                'starts_at': '2026-09-07 07:00:00.000Z',
                'ends_at': '2026-09-07 08:00:00.000Z',
                'instructor': 'i1',
                'car': 'c1',
                'cadet': 'k1',
              }
            ]
          }));
      final slots = await PocketBaseRepository(makeDio(adapter)).busy(
          from: DateTime.utc(2026, 9, 7, 6),
          to: DateTime.utc(2026, 9, 7, 9),
          instructor: 'i1');
      expect(adapter.log, ['GET /api/autoschool/busy']);
      expect(adapter.requests.single.uri.queryParameters['instructor'], 'i1');
      expect(slots.single.instructor, 'i1');
      expect(
          slots.single.overlaps(
              DateTime.utc(2026, 9, 7, 7, 30), DateTime.utc(2026, 9, 7, 8, 30)),
          isTrue);
    });
  });
}
