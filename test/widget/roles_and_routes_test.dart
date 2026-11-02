import 'package:autoschool_client/auth/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Finder inMenu(String text) =>
    find.descendant(of: find.byType(NavigationRail), matching: find.text(text));

void main() {
  setUpAll(loadTestFonts);

  group('меню зависит от роли', () {
    testWidgets('администратор: всё управление', (tester) async {
      final h = await pumpSchool(tester, role: Role.admin);
      for (final item in [
        'Пользователи',
        'Отчёт',
        'Платежи',
        'Курсанты',
        'Автомобили',
        'Занятия'
      ]) {
        expect(inMenu(item), findsOneWidget, reason: item);
      }
      expect(inMenu('Запись на вождение'), findsNothing);
      await h.close();
    });

    testWidgets('инструктор: расписание и курсанты, без денег и учёток',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.instructor);
      for (final item in ['Расписание', 'Курсанты', 'Прогресс', 'Занятия']) {
        expect(inMenu(item), findsOneWidget, reason: item);
      }
      for (final item in [
        'Платежи',
        'Пользователи',
        'Отчёт',
        'Запись на вождение'
      ]) {
        expect(inMenu(item), findsNothing, reason: item);
      }
      await h.close();
    });

    testWidgets('курсант: запись на вождение, свой прогресс и платежи',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.cadet);
      for (final item in [
        'Запись на вождение',
        'Мой прогресс',
        'Мои платежи',
        'Мой профиль'
      ]) {
        expect(inMenu(item), findsOneWidget, reason: item);
      }
      for (final item in ['Пользователи', 'Отчёт', 'Платежи']) {
        expect(inMenu(item), findsNothing, reason: item);
      }
      await h.close();
    });
  });

  group('защищённые маршруты', () {
    testWidgets('гость, открывший закрытый адрес, попадает на вход',
        (tester) async {
      final h = await pumpSchool(tester, location: '/cadets');
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(h.location, startsWith('/login'));
      await h.close();
    });

    testWidgets('курсант не открывает раздел «Пользователи» вручную',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.cadet, location: '/users');
      expect(find.text('Доступ запрещён'), findsOneWidget);
      expect(find.textContaining('для роли «Курсант»'), findsOneWidget);
      await h.close();
    });

    testWidgets('инструктор не открывает отчёт и платежи', (tester) async {
      final h = await pumpSchool(tester, role: Role.instructor);
      await h.go('/report');
      expect(find.text('Доступ запрещён'), findsOneWidget);
      await h.go('/payments');
      expect(find.text('Доступ запрещён'), findsOneWidget);
      await h.close();
    });

    testWidgets('курсант не открывает форму создания автомобиля',
        (tester) async {
      final h =
          await pumpSchool(tester, role: Role.cadet, location: '/cars/new');
      expect(find.text('Доступ запрещён'), findsOneWidget);
      await h.close();
    });

    testWidgets('администратор попадает в отчёт без отказа', (tester) async {
      final h = await pumpSchool(tester, role: Role.admin, location: '/report');
      expect(find.text('Доступ запрещён'), findsNothing);
      await h.close();
    });

    testWidgets('несуществующий адрес — страница «не найдено»', (tester) async {
      final h = await pumpSchool(tester,
          role: Role.admin, location: '/такой-страницы-нет');
      expect(find.text('Страница не найдена'), findsOneWidget);
      await h.close();
    });

    testWidgets('курсант без анкеты сначала заполняет анкету', (tester) async {
      const newCadet = Account('new@autoschool.test', 'Autoschool123!',
          Role.cadet, 'Новый Курсант', 'u_new');
      final h = await pumpSchool(tester, account: newCadet);
      expect(find.text('Заполните анкету курсанта'), findsWidgets);
      await h.go('/cadets');
      expect(find.text('Заполните анкету курсанта'), findsWidgets,
          reason: 'пока анкеты нет, другие разделы закрыты');
      await h.close();
    });
  });
}
