import 'package:autoschool_client/auth/permissions.dart';
import 'package:autoschool_client/core/connection.dart';
import 'package:autoschool_client/state/load_status.dart';
import 'package:autoschool_client/widgets/connection_banner.dart';
import 'package:autoschool_client/widgets/state_views.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import '../support/test_app.dart';

Widget host(Widget child) => MaterialApp(home: Scaffold(body: child));

ListStateView listView({
  required LoadStatus status,
  bool hasData = false,
  String? error,
  VoidCallback? onRetry,
  VoidCallback? onReset,
}) =>
    ListStateView(
      status: status,
      error: error,
      hasData: hasData,
      emptyTitle: 'Курсантов не найдено',
      emptyMessage: 'Измените условия поиска.',
      onRetry: onRetry ?? () {},
      onResetFilters: onReset,
      child: const Text('данные'),
    );

void main() {
  setUpAll(loadTestFonts);

  group('четыре состояния списка', () {
    testWidgets('загрузка: индикатор, данных ещё нет', (tester) async {
      await tester.pumpWidget(host(listView(status: LoadStatus.loading)));
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('данные'), findsNothing);
    });

    testWidgets('пусто: сообщение и сброс фильтров', (tester) async {
      var reset = 0;
      await tester.pumpWidget(
          host(listView(status: LoadStatus.success, onReset: () => reset++)));
      expect(find.text('Курсантов не найдено'), findsOneWidget);
      await tester.tap(find.text('Сбросить фильтры'));
      expect(reset, 1);
    });

    testWidgets(
        'ошибка: сообщение и «Повторить», не выглядит как пустой список',
        (tester) async {
      var retries = 0;
      await tester.pumpWidget(host(listView(
        status: LoadStatus.error,
        error: 'Сервер недоступен.',
        onRetry: () => retries++,
      )));
      expect(find.text('Сервер недоступен.'), findsOneWidget);
      expect(find.text('Курсантов не найдено'), findsNothing);
      await tester.tap(find.text('Повторить'));
      expect(retries, 1);
    });

    testWidgets('данные есть: показывается содержимое', (tester) async {
      await tester.pumpWidget(
          host(listView(status: LoadStatus.success, hasData: true)));
      expect(find.text('данные'), findsOneWidget);
    });
  });

  group('связь с сервером', () {
    testWidgets('полоса над приложением появляется и пропадает сама',
        (tester) async {
      final connection = ConnectionNotifier();
      await tester.pumpWidget(host(ConnectionBanner(connection: connection)));
      expect(find.byIcon(Icons.cloud_off), findsNothing);

      connection.reportFailure();
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsOneWidget);

      connection.reportSuccess();
      await tester.pump();
      expect(find.byIcon(Icons.cloud_off), findsNothing);

      await tester.pumpWidget(const SizedBox.shrink());
      connection.dispose();
    });

    testWidgets('экран ошибки сам повторяет запрос, когда связь вернулась',
        (tester) async {
      final connection = ConnectionNotifier();
      var retries = 0;
      await tester.pumpWidget(ChangeNotifierProvider.value(
        value: connection,
        child:
            host(ErrorView(message: 'Нет ответа.', onRetry: () => retries++)),
      ));

      connection.reportFailure();
      await tester.pump();
      expect(retries, 0);
      connection.reportSuccess();
      await tester.pump();
      expect(retries, 1, reason: 'экран сам повторил запрос');

      await tester.pumpWidget(const SizedBox.shrink());
      connection.dispose();
    });
  });

  group('экраны ролей', () {
    testWidgets('курсант на главной видит ближайшее занятие', (tester) async {
      final h = await pumpSchool(tester, role: Role.cadet);
      expect(find.text('Ближайшие занятия'), findsOneWidget);
      expect(find.textContaining('Кузнецов Андрей Сергеевич'), findsWidgets);
      expect(find.text('Записаться на вождение'), findsOneWidget);
      await h.close();
    });

    testWidgets('администратор на главной видит счётчики школы',
        (tester) async {
      final h = await pumpSchool(tester, role: Role.admin);
      expect(find.text('Курсантов обучается'), findsOneWidget);
      expect(find.text('Автомобилей в эксплуатации'), findsOneWidget);
      await h.close();
    });

    testWidgets('курсант открывает запись на вождение', (tester) async {
      final h = await pumpSchool(tester, role: Role.cadet, location: '/book');
      expect(find.text('Доступ запрещён'), findsNothing);
      expect(tester.takeException(), isNull);
      await h.close();
    });

    testWidgets('прогресс курсанта: условия допуска к экзамену',
        (tester) async {
      final h =
          await pumpSchool(tester, role: Role.cadet, location: '/progress');
      expect(find.textContaining('Теоретический экзамен сдан'), findsOneWidget);
      expect(find.textContaining('Экзамен на площадке сдан'), findsOneWidget);
      await h.close();
    });
  });
}
