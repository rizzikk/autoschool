import 'package:autoschool_client/auth/permissions.dart';
import 'package:autoschool_client/repositories/in_memory_repository.dart';
import 'package:autoschool_client/widgets/debounced_text_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

void main() {
  setUpAll(loadTestFonts);

  group('адаптивность: ширина 360, 768, 1280 и 1920', () {
    for (final entry in testWidths.entries) {
      for (final path in ['/', '/cadets', '/lessons', '/categories/new']) {
        testWidgets('${entry.key}px, $path: без переполнения', (tester) async {
          final h = await pumpSchool(tester,
              role: Role.admin, size: entry.value, location: path);

          expect(tester.takeException(), isNull);
          expect(find.byType(Scaffold), findsWidgets);
          if (entry.key < 600) {
            expect(find.byType(NavigationBar), findsOneWidget,
                reason: 'на телефоне — нижняя панель');
            expect(find.byType(NavigationRail), findsNothing);
          } else {
            expect(find.byType(NavigationRail), findsOneWidget,
                reason: 'на планшете и мониторе — боковая панель');
            expect(find.byType(NavigationBar), findsNothing);
          }
          await h.close();
        });
      }
    }

    testWidgets('телефон: вход без переполнения', (tester) async {
      final h = await pumpSchool(tester, size: testWidths[360]!);
      expect(tester.takeException(), isNull);
      expect(find.text('Войти'), findsOneWidget);
      await h.close();
    });

    testWidgets('телефон: курсант листает меню через «Ещё»', (tester) async {
      final h = await pumpSchool(tester,
          role: Role.cadet, size: testWidths[360]!, location: '/');
      expect(find.text('Ещё'), findsOneWidget);
      await tester.tap(find.byIcon(Icons.more_horiz));
      await settle(tester, 'после открытия «Ещё»');
      final payments = find.descendant(
          of: find.byType(BottomSheet), matching: find.text('Мои платежи'));
      await tester.scrollUntilVisible(
        payments,
        100,
        scrollable: find.descendant(
            of: find.byType(BottomSheet), matching: find.byType(Scrollable)),
      );
      expect(payments, findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.close();
    });

    InMemoryRepository manyCadets() => InMemoryRepository(relations: const {
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

    testWidgets(
        'телефон: заголовок и номера страниц прокручиваются вместе с карточками',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin,
          size: testWidths[360]!,
          repository: manyCadets(),
          location: '/cadets?sort=full_name');

      final height = tester.view.physicalSize.height;
      final cards = find.byType(Card);
      var onScreen = 0;
      for (var i = 0; i < cards.evaluate().length; i++) {
        if (tester.getRect(cards.at(i)).bottom <= height) onScreen++;
      }
      expect(onScreen, greaterThanOrEqualTo(2),
          reason: 'на экране телефона помещается не одна карточка');

      final search = find.byType(DebouncedTextField);
      final top = tester.getRect(search).top;
      await tester.drag(cards.first, const Offset(0, -200));
      await tester.pump();
      expect(tester.getRect(search).top, lessThan(top - 100));

      final pager = find.text('Записи 1–10 из 25');
      await tester.scrollUntilVisible(pager, 200,
          scrollable: find
              .descendant(
                  of: find.byType(ListView), matching: find.byType(Scrollable))
              .first);
      expect(pager, findsOneWidget);
      await tester.tap(find.byTooltip('Следующая страница'));
      await settle(tester, 'на второй странице');
      expect(find.text('Записи 11–20 из 25'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await h.close();
    });

    testWidgets('телефон: текст поиска не пропадает, когда ничего не найдено',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin,
          size: testWidths[360]!,
          repository: manyCadets(),
          location: '/cadets');
      final field = find.descendant(
          of: find.byType(DebouncedTextField),
          matching: find.byType(TextField));

      await tester.enterText(field, 'Несуществующий');
      await tester.pump(const Duration(milliseconds: 700));
      await settle(tester, 'после поиска без результата');

      expect(find.text('Ничего не найдено'), findsOneWidget);
      expect(
          tester.widget<TextField>(field).controller!.text, 'Несуществующий');
      expect(Uri.decodeFull(h.location), contains('q=Несуществующий'));
      await h.close();
    });

    testWidgets('1280 px: «Действия» закреплены, кнопки стоят напротив строк',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, size: testWidths[1280]!, location: '/lessons');
      final edits = find.byTooltip('Изменить');
      expect(edits, findsWidgets);
      expect(find.text('Действия'), findsOneWidget);
      final width = tester.view.physicalSize.width;
      final rows = find.descendant(
          of: find.byType(DataTable), matching: find.byType(Checkbox));
      for (var i = 0; i < edits.evaluate().length; i++) {
        final edit = tester.getCenter(edits.at(i));
        expect(edit.dx, lessThan(width), reason: 'кнопка не уехала за край');
        final box = tester.getCenter(rows.at(i + 1));
        expect((edit.dy - box.dy).abs(), lessThan(1),
            reason: 'кнопка строки $i на одной высоте с флажком строки');
      }
      expect(tester.takeException(), isNull);
      await h.close();
    });

    testWidgets(
        '1280 px: у курсанта в справочнике нет пустой колонки «Действия»',
        (tester) async {
      final h = await pumpSchool(tester,
          role: Role.cadet, size: testWidths[1280]!, location: '/cars');
      expect(find.byType(DataTable), findsOneWidget);
      expect(find.text('Действия'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.close();
    });

    for (final width in [360, 1280]) {
      testWidgets('$width px: меню и «Выйти» есть в дереве семантики',
          (tester) async {
        final semantics = tester.ensureSemantics();
        final h = await pumpSchool(tester,
            role: Role.admin, size: testWidths[width]!, location: '/cars');
        if (width < 600) {
          expect(tester.getSemantics(find.byTooltip('Выйти')), isNotNull);
          expect(find.bySemanticsLabel(RegExp('Ещё')), findsWidgets);
        } else {
          expect(find.bySemanticsLabel(RegExp('Выйти')), findsWidgets);
          expect(find.bySemanticsLabel(RegExp('Главная')), findsWidgets);
        }
        await h.close();
        semantics.dispose();
      });
    }
  });
}
