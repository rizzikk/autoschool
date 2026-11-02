import 'package:autoschool_client/auth/permissions.dart';
import 'package:autoschool_client/repositories/in_memory_repository.dart';
import 'package:autoschool_client/widgets/debounced_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/flaky_repository.dart';
import '../support/test_app.dart';

void main() {
  setUpAll(loadTestFonts);

  group('список сущности', () {
    testWidgets('администратор видит записи, кнопку добавления и колонки',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.admin, location: '/cadets');

      expect(find.text('Иванова Мария Петровна'), findsOneWidget);
      expect(find.text('Петров Пётр Сергеевич'), findsOneWidget);
      expect(find.text('Сидорова Анна Ильинична'), findsOneWidget);
      expect(find.text('Добавить курсанта'), findsOneWidget);
      await h.close();
    });

    testWidgets('инструктор видит список, но не кнопку добавления',
        (tester) async {
      final h =
          await pumpSchool(tester, role: Role.instructor, location: '/cadets');

      expect(find.text('Иванова Мария Петровна'), findsOneWidget);
      expect(find.text('Добавить курсанта'), findsNothing);
      await h.close();
    });

    testWidgets('поиск идёт на сервер и попадает в адрес страницы',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.admin, location: '/cadets');

      await tester.enterText(
          find.descendant(
              of: find.byType(DebouncedTextField),
              matching: find.byType(TextField)),
          'Сидорова');
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester, 'после поиска');

      expect(find.text('Сидорова Анна Ильинична'), findsOneWidget);
      expect(find.text('Иванова Мария Петровна'), findsNothing);
      expect(find.text('Петров Пётр Сергеевич'), findsNothing);
      expect(Uri.decodeFull(h.location), contains('q=Сидорова'));
      await h.close();
    });

    testWidgets('ничего не найдено: пустое состояние, а не ошибка',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/cadets?q=Несуществующий');

      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(find.text('Повторить'), findsNothing);
      await h.close();
    });

    testWidgets('условия отбора из адреса применяются при открытии',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/cadets?status=graduated');

      expect(find.text('Сидорова Анна Ильинична'), findsOneWidget);
      expect(find.text('Иванова Мария Петровна'), findsNothing);
      await h.close();
    });

    testWidgets('корзина: удалённые видны администратору', (tester) async {
      final repo = makeSchoolRepository();
      await repo.update('cadets', 'k3', {'deleted': true});
      final h = await pumpSchool(tester,
          role: Role.admin, repository: repo, location: '/cadets');
      expect(find.text('Сидорова Анна Ильинична'), findsNothing);

      await h.go('/cadets?deleted=only');
      expect(find.text('Сидорова Анна Ильинична'), findsOneWidget);
      expect(find.text('Иванова Мария Петровна'), findsNothing);
      await h.close();
    });

    testWidgets('инструктору параметр корзины из адреса молча убирается',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.instructor, location: '/cadets?deleted=only');
      expect(h.location, isNot(contains('deleted')));
      await h.close();
    });

    testWidgets('страницы: на 25 записей при размере 10 доступна вторая',
        (tester) async {
      final repo = InMemoryRepository(relations: const {
        'cadets': {'category': 'categories'},
      }, data: {
        'categories': [
          {'id': 'catB', 'code': 'B', 'title': 'Легковой'}
        ],
        'cadets': [
          for (var i = 1; i <= 25; i++)
            {
              'id': 'k$i',
              'full_name': 'Курсант ${i.toString().padLeft(2, '0')}',
              'category': 'catB',
              'status': 'studying',
              'enrolled_at': '2026-02-01 00:00:00.000Z',
            }
        ],
      });
      final h = await pumpSchool(tester,
          role: Role.admin,
          repository: repo,
          location: '/cadets?sort=full_name');

      expect(find.text('Записи 1–10 из 25'), findsOneWidget);
      await tester.tap(find.byTooltip('Следующая страница'));
      await settle(tester, 'на второй странице');

      expect(find.text('Записи 11–20 из 25'), findsOneWidget);
      expect(h.location, contains('page=2'));
      expect(find.text('Курсант 11'), findsOneWidget);
      await h.close();
    });

    testWidgets(
        'сервер недоступен: ошибка с кнопкой, потом самовосстановление по нажатию',
        (tester) async {
      final flaky = FlakyRepository(makeSchoolRepository());
      final h = await pumpSchool(tester,
          role: Role.admin, repository: flaky, location: '/categories');
      expect(find.text('Легковой автомобиль'), findsWidgets);

      flaky.down = true;
      await h.go('/cadets');
      expect(find.text('Повторить'), findsOneWidget);
      expect(find.text('Иванова Мария Петровна'), findsNothing);

      flaky.down = false;
      await tester.tap(find.text('Повторить'));
      await settle(tester, 'после повтора');
      expect(find.text('Иванова Мария Петровна'), findsOneWidget);
      await h.close();
    });
  });
}
