import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:autoschool_client/repositories/conditions.dart';
import 'package:autoschool_client/repositories/in_memory_repository.dart';
import 'package:autoschool_client/repositories/record_repository.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/records.dart';

InMemoryRepository makeRepo() => InMemoryRepository(
      relations: const {
        'cadets': {'category': 'categories'},
        'lessons': {'cadet': 'cadets'},
      },
      data: {
        'categories': [
          {'id': 'catB', 'title': 'Легковой'},
        ],
        'cadets': [
          for (var i = 1; i <= 12; i++)
            {
              'id': 'k$i',
              'full_name': 'Курсант ${i.toString().padLeft(2, '0')}',
              'category': 'catB',
              'status': i.isEven ? 'studying' : 'graduated',
              'deleted': i == 12,
            }
        ],
        'lessons': [
          {
            'id': 'l1',
            'cadet': 'k1',
            'instructor': 'i1',
            'car': 'c1',
            'status': 'planned',
            'starts_at': utc(2026, 9, 7, 7),
            'ends_at': utc(2026, 9, 7, 8),
          }
        ],
      },
    );

void main() {
  group('InMemoryRepository ведёт себя как сервер', () {
    test('страницы: размер, номер, общее число', () async {
      final r = await makeRepo().list('cadets',
          perPage: 5,
          page: 2,
          sort: 'full_name',
          where: const Eq('deleted', false));
      expect(r.total, 11);
      expect(r.items.length, 5);
      expect(r.items.first.str('full_name'), 'Курсант 06');
      expect(r.hasNext, isTrue);
    });

    test('сортировка по убыванию', () async {
      final r = await makeRepo().list('cadets',
          sort: '-full_name', where: const Eq('deleted', false));
      expect(r.items.first.str('full_name'), 'Курсант 11');
    });

    test('фильтры по полю и поиск по подстроке', () async {
      final repo = makeRepo();
      final studying = await repo.listAll('cadets',
          where: const And([Eq('status', 'studying'), Eq('deleted', false)]));
      expect(studying.length, 5);
      final found =
          await repo.listAll('cadets', where: const Like('full_name', '07'));
      expect(found.map((e) => e.id), ['k7']);
    });

    test('expand раскрывает связанную запись', () async {
      final l = await makeRepo().find('lessons', 'l1', expand: 'cadet');
      expect(l!.one('cadet')!.id, 'k1');
    });

    test('поиск по полю связанной записи через точку', () async {
      final found = await makeRepo().listAll('lessons',
          where: const Like('cadet.full_name', 'Курсант 01'));
      expect(found.length, 1);
    });

    test('создание присваивает id и значение deleted=false', () async {
      final repo = makeRepo();
      final created = await repo.create('categories', {'title': 'Мото'});
      expect(created.id, isNotEmpty);
      expect(created.deleted, isFalse);
      expect(repo.count('categories'), 2);
    });

    test('мягкое удаление: запись остаётся, восстановление возвращает её',
        () async {
      final repo = makeRepo();
      await repo.update('cadets', 'k2', {'deleted': true});
      expect(
          (await repo.listAll('cadets', where: const Eq('deleted', false)))
              .length,
          10);
      await repo.update('cadets', 'k2', {'deleted': false});
      expect(
          (await repo.listAll('cadets', where: const Eq('deleted', false)))
              .length,
          11);
    });

    test('физическое удаление запрещено, пока есть ссылки (409)', () async {
      final repo = makeRepo();
      await expectLater(
          repo.delete('cadets', 'k1'), throwsA(isA<ConflictException>()));
      await repo.delete('cadets', 'k3');
      expect(await repo.find('cadets', 'k3'), isNull);
    });

    test('изменение несуществующей записи — NotFound', () async {
      await expectLater(makeRepo().update('cadets', 'нет', {'a': 1}),
          throwsA(isA<NotFoundException>()));
    });

    test('busy: занятые интервалы пересекаются с запрошенным окном', () async {
      final repo = makeRepo();
      final hit = await repo.busy(
          from: DateTime.utc(2026, 9, 7, 7, 30),
          to: DateTime.utc(2026, 9, 7, 9),
          instructor: 'i1');
      expect(hit.length, 1);
      expect(hit.single, isA<BusySlot>());
      final miss = await repo.busy(
          from: DateTime.utc(2026, 9, 7, 8),
          to: DateTime.utc(2026, 9, 7, 9),
          instructor: 'i1');
      expect(miss, isEmpty);
    });
  });
}
