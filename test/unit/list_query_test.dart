import 'package:autoschool_client/domain/entities.dart';
import 'package:autoschool_client/models/list_query.dart';
import 'package:autoschool_client/repositories/pb_filter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ListQuery: условия отбора живут в адресе страницы', () {
    test('разбор параметров адреса', () {
      final q = cadetsDef.queryFromParams({
        'q': ' иван ',
        'status': 'studying',
        'sort': 'full_name,desc',
        'page': '3',
        'size': '25',
        'deleted': 'only',
      });
      expect(q.search, 'иван');
      expect(q.filters, {'status': 'studying'});
      expect(q.sortField, 'full_name');
      expect(q.sortAscending, isFalse);
      expect(q.page, 3);
      expect(q.size, 25);
      expect(q.deleted, DeletedMode.only);
    });

    test('мусор в адресе заменяется значениями по умолчанию', () {
      final q = cadetsDef.queryFromParams({
        'sort': 'password,desc',
        'page': '-5',
        'size': '9999',
        'unknown': 'x',
      });
      expect(q.sortField, cadetsDef.defaultSort);
      expect(q.page, 1);
      expect(q.size, defaultPageSizeForTest);
      expect(q.filters, isEmpty);
    });

    test('параметры → запрос → параметры: ничего не теряется', () {
      final params = {
        'q': 'пет',
        'status': 'studying',
        'sort': 'full_name,desc',
        'page': '2',
      };
      expect(cadetsDef.queryFromParams(params).toParams(), params);
    });

    test('смена фильтра возвращает на первую страницу', () {
      final q = cadetsDef.queryFromParams({'page': '4'});
      expect(q.page, 4);
      expect(q.withFilter('status', 'graduated').page, 1);
    });
  });

  group('EntityDef.buildCond: запрос списка', () {
    test('по умолчанию корзина скрыта', () {
      final q = cadetsDef.queryFromParams(const {});
      expect(toPbFilter(cadetsDef.buildCond(q, canSeeDeleted: true)),
          'deleted = false');
    });

    test('корзину открывает только право просмотра удалённых', () {
      final q = cadetsDef.queryFromParams({'deleted': 'only'});
      expect(toPbFilter(cadetsDef.buildCond(q, canSeeDeleted: true)),
          'deleted = true');
      expect(toPbFilter(cadetsDef.buildCond(q, canSeeDeleted: false)),
          'deleted = false');
    });

    test('поиск и три фильтра складываются через «И»', () {
      final q = cadetsDef.queryFromParams({
        'q': 'иван',
        'status': 'studying',
        'category': 'b1',
        'from': '2026-01-01',
      });
      final f = toPbFilter(cadetsDef.buildCond(q, canSeeDeleted: false));
      expect(f, contains("status = 'studying'"));
      expect(f, contains("category = 'b1'"));
      expect(f, contains('enrolled_at >= '));
      expect(f, contains('full_name ~'));
    });
  });
}

const defaultPageSizeForTest = 10;
