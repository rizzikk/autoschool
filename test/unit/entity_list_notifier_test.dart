import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:autoschool_client/domain/entities.dart';
import 'package:autoschool_client/models/list_query.dart';
import 'package:autoschool_client/repositories/in_memory_repository.dart';
import 'package:autoschool_client/state/entity_list_notifier.dart';
import 'package:autoschool_client/state/load_status.dart';
import 'package:flutter_test/flutter_test.dart';

InMemoryRepository makeRepo() => InMemoryRepository(
      relations: const {
        'cadets': {'category': 'categories'},
        'lessons': {'cadet': 'cadets'},
      },
      data: {
        'categories': [
          {'id': 'catB', 'title': 'Легковой'}
        ],
        'cadets': [
          for (var i = 1; i <= 7; i++)
            {
              'id': 'k$i',
              'full_name': 'Курсант $i',
              'category': 'catB',
              'status': 'studying',
            }
        ],
        'lessons': [
          {'id': 'l1', 'cadet': 'k1', 'starts_at': '2026-09-07 07:00:00.000Z'}
        ],
      },
    );

void main() {
  late EntityListNotifier n;

  setUp(() async {
    n = EntityListNotifier(cadetsDef, makeRepo(), canSeeDeleted: true);
    await n.load();
  });

  tearDown(() => n.dispose());

  group('EntityListNotifier: список, корзина, групповые операции', () {
    test('загрузка первой страницы', () {
      expect(n.status, LoadStatus.success);
      expect(n.result.total, 7);
    });

    test('смена условий сбрасывает выделение', () async {
      n.toggleSelection('k2');
      expect(n.selected, {'k2'});
      await n.applyQuery(n.query.copyWith(search: 'Курсант 3'));
      expect(n.selected, isEmpty);
      expect(n.result.total, 1);
    });

    test('мягкое удаление убирает запись из списка, корзина её показывает',
        () async {
      await n.softDelete('k2');
      expect(n.result.total, 6);
      await n.applyQuery(n.query.copyWith(deleted: DeletedMode.only));
      expect(n.result.items.map((e) => e.id), ['k2']);
    });

    test('восстановление возвращает запись в список', () async {
      await n.softDelete('k2');
      await n.restore('k2');
      expect(n.result.total, 7);
    });

    test('групповое мягкое удаление выделенных', () async {
      n.setSelection(['k3', 'k4', 'k5'], true);
      final r = await n.softDeleteSelected();
      expect(r.done, 3);
      expect(r.hasErrors, isFalse);
      expect(n.result.total, 4);
      expect(n.selected, isEmpty);
    });

    test(
        'групповое физическое удаление: ошибка по одной записи не мешает остальным',
        () async {
      n.setSelection(['k1', 'k6', 'k7'], true);
      final r = await n.hardDeleteSelected();
      expect(r.done, 2);
      expect(r.failed.length, 1);
      expect(r.failed.single, contains('ссылаются'));
    });

    test('одиночное физическое удаление записи со ссылками — ConflictException',
        () async {
      await expectLater(n.hardDelete('k1'), throwsA(isA<ConflictException>()));
    });
  });
}
