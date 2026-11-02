import 'package:autoschool_client/auth/permissions.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../support/test_app.dart';

Finder field(String label) => find.byWidgetPredicate(
    (w) => w is TextField && w.decoration?.labelText == label,
    description: 'поле «$label»');

void main() {
  setUpAll(loadTestFonts);

  group('вход и регистрация', () {
    testWidgets('без входа открывается экран входа', (tester) async {
      final h = await pumpSchool(tester);
      expect(find.text('Вход в систему'), findsOneWidget);
      expect(find.text('Автошкола'), findsWidgets);
      await h.close();
    });

    testWidgets('пустая форма не отправляется: подсказки под полями',
        (tester) async {
      final h = await pumpSchool(tester);
      await tester.tap(find.text('Войти'));
      await settle(tester, 'после нажатия «Войти»');

      expect(find.text('Введите почту'), findsOneWidget);
      expect(find.text('Введите пароль'), findsOneWidget);
      await h.close();
    });

    testWidgets('неверный пароль: сообщение на экране, вход не выполнен',
        (tester) async {
      final h = await pumpSchool(tester);
      await tester.enterText(
          field('Электронная почта'), 'admin@autoschool.test');
      await tester.enterText(field('Пароль'), 'неверный-пароль');
      await tester.tap(find.text('Войти'));
      await settle(tester, 'после попытки входа');

      expect(find.text('Неверная почта или пароль.'), findsOneWidget);
      expect(h.auth.isAuthenticated, isFalse);
      await h.close();
    });

    testWidgets('верный пароль: открывается главная страница роли',
        (tester) async {
      final h = await pumpSchool(tester);
      await tester.enterText(
          field('Электронная почта'), 'admin@autoschool.test');
      await tester.enterText(field('Пароль'), 'Autoschool123!');
      await tester.tap(find.text('Войти'));
      await settle(tester, 'после входа');

      expect(find.text('Здравствуйте, Администратор системы'), findsOneWidget);
      expect(h.auth.role, Role.admin);
      await h.close();
    });

    testWidgets('вход сохраняется после обновления страницы', (tester) async {
      final h = await pumpSchool(tester, role: Role.instructor);
      expect(find.text('Вход в систему'), findsNothing);
      expect(
          find.text('Здравствуйте, Кузнецов Андрей Сергеевич'), findsOneWidget);
      await h.close();
    });

    testWidgets('выход возвращает на экран входа и стирает сессию',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.admin);
      await h.auth.logout();
      await settle(tester, 'после выхода');

      expect(find.text('Вход в систему'), findsOneWidget);
      expect(h.auth.user, isNull);
      await h.close();
    });

    testWidgets('регистрация: несовпадающие пароли — ошибка под полем',
        (tester) async {
      final h = await pumpSchool(tester, location: '/register');
      await tester.enterText(field('Имя и фамилия'), 'Новый Курсант');
      await tester.enterText(field('Почта'), 'new@autoschool.test');
      await tester.enterText(field('Пароль'), 'Qwerty123!x');
      await tester.enterText(field('Пароль ещё раз'), 'Qwerty123!y');
      await tester.tap(find.text('Зарегистрироваться').last);
      await settle(tester, 'после нажатия «Зарегистрироваться»');

      expect(find.text('Пароли не совпадают'), findsOneWidget);
      await h.close();
    });
  });
}
