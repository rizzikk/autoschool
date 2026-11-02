import 'package:autoschool_client/auth/permissions.dart';
import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
    (w) =>
        w is TextField &&
        (w.decoration?.labelText == label ||
            w.decoration?.labelText == '$label *'),
    description: 'поле «$label»');

Future<void> fillCategory(WidgetTester tester,
    {String code = 'M', String title = 'Мотороллер'}) async {
  await tester.enterText(field('Код'), code);
  await tester.enterText(field('Название'), title);
  await tester.enterText(field('Минимальный возраст'), '16');
  await tester.enterText(field('Часов теории'), '100');
  await tester.enterText(field('Часов вождения'), '18');
  await tester.enterText(field('Стоимость, ₽'), '20000');
}

void main() {
  setUpAll(loadTestFonts);

  group('форма создания', () {
    testWidgets('пустая форма не отправляется, под полями — подсказки',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/categories/new');
      final before = (h.repo as dynamic).count('categories');

      await tester.tap(find.text('Создать'));
      await settle(tester, 'после нажатия «Создать»');

      expect(find.text('Обязательное поле'), findsAtLeastNWidgets(4));
      expect((h.repo as dynamic).count('categories'), before,
          reason: 'запись не создана');
      await h.close();
    });

    testWidgets('значения вне допустимых пределов: клиентская проверка',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/categories/new');
      await fillCategory(tester, code: 'ABCDE');
      await tester.enterText(field('Минимальный возраст'), '5');
      await tester.tap(find.text('Создать'));
      await settle(tester, 'после нажатия «Создать»');

      expect(find.textContaining('Не длиннее 4'), findsOneWidget);
      expect(find.text('Не меньше 14'), findsOneWidget);
      await h.close();
    });

    testWidgets('верные данные: запись создаётся, открывается её карточка',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/categories/new');
      final before = (h.repo as dynamic).count('categories') as int;

      await fillCategory(tester);
      await tester.tap(find.text('Создать'));
      await settle(tester, 'после создания');

      expect((h.repo as dynamic).count('categories'), before + 1);
      expect(h.location, startsWith('/categories/'));
      expect(h.location, isNot(contains('/new')));
      await h.close();
    });

    testWidgets('ошибка сервера по полю показывается под этим полем',
        (tester) async {
      final repo = makeSchoolRepository(validator: (op, collection, body) {
        if (collection == 'categories' && body['title'] == 'Занято') {
          throw const ValidationException('Проверьте значения полей формы.',
              {'title': 'Категория с таким названием уже есть'});
        }
      });
      final h = await pumpSchool(tester,
          role: Role.admin, repository: repo, location: '/categories/new');

      await fillCategory(tester, title: 'Занято');
      await tester.tap(find.text('Создать'));
      await settle(tester, 'после ответа сервера');

      expect(find.text('Категория с таким названием уже есть'), findsOneWidget);
      expect(h.location, '/categories/new', reason: 'форма осталась открытой');
      await h.close();
    });
  });

  group('форма изменения', () {
    testWidgets('поля заполнены значениями записи', (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/categories/catB/edit');

      final code = tester.widget<TextField>(field('Код'));
      expect(code.controller!.text, 'B');
      final price = tester.widget<TextField>(field('Стоимость, ₽'));
      expect(price.controller!.text, '38000');
      await h.close();
    });

    testWidgets('сохранение меняет запись', (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/categories/catB/edit');

      await tester.enterText(field('Название'), 'Легковой, механика');
      await tester.tap(find.text('Сохранить изменения'));
      await settle(tester, 'после сохранения');

      final saved = await h.repo.find('categories', 'catB');
      expect(saved!.str('title'), 'Легковой, механика');
      await h.close();
    });

    testWidgets('несуществующая запись: сообщение, а не пустая форма',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/categories/нет-такой/edit');
      expect(find.text('Запись не найдена'), findsOneWidget);
      await h.close();
    });
  });
}
