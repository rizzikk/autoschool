import 'dart:convert';
import 'dart:io';

import 'package:autoschool_client/auth/app_user.dart';
import 'package:autoschool_client/auth/auth_api.dart';
import 'package:autoschool_client/auth/auth_notifier.dart';
import 'package:autoschool_client/auth/permissions.dart';
import 'package:autoschool_client/bootstrap.dart';
import 'package:autoschool_client/core/api_exceptions.dart';
import 'package:autoschool_client/core/connection.dart';
import 'package:autoschool_client/core/session.dart';
import 'package:autoschool_client/domain/entities.dart';
import 'package:autoschool_client/repositories/in_memory_repository.dart';
import 'package:autoschool_client/repositories/record_repository.dart';
import 'package:autoschool_client/util/format.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';

Future<void> loadTestFonts() async {
  final loader = FontLoader('Roboto');
  for (final name in ['Regular', 'Medium']) {
    loader.addFont(File('test/fonts/Roboto-$name.ttf')
        .readAsBytes()
        .then((bytes) => ByteData.sublistView(bytes)));
  }
  await loader.load();
}

const testWidths = <int, Size>{
  360: Size(360, 800),
  768: Size(768, 1024),
  1280: Size(1280, 800),
  1920: Size(1920, 1080),
};

String fakeJwt({Duration lifetime = const Duration(hours: 1)}) {
  String part(Map<String, Object?> m) =>
      base64Url.encode(utf8.encode(jsonEncode(m))).replaceAll('=', '');
  final exp = DateTime.now().add(lifetime).millisecondsSinceEpoch ~/ 1000;
  return '${part({'alg': 'HS256'})}.${part({'exp': exp})}.sig';
}

class Account {
  const Account(this.email, this.password, this.role, this.name, this.id,
      {this.profileId});

  final String email;
  final String password;
  final Role role;
  final String name;
  final String id;
  final String? profileId;
}

const adminAccount = Account('admin@autoschool.test', 'Autoschool123!',
    Role.admin, 'Администратор системы', 'u_admin');
const instructorAccount = Account('instructor@autoschool.test',
    'Autoschool123!', Role.instructor, 'Кузнецов Андрей Сергеевич', 'u_instr',
    profileId: 'i1');
const cadetAccount = Account('cadet@autoschool.test', 'Autoschool123!',
    Role.cadet, 'Иванова Мария Петровна', 'u_cadet',
    profileId: 'k1');

Account accountFor(Role role) => switch (role) {
      Role.admin => adminAccount,
      Role.instructor => instructorAccount,
      Role.cadet => cadetAccount,
    };

class FakeAuthApi implements AuthApi {
  FakeAuthApi({List<Account>? accounts})
      : accounts = accounts ?? [adminAccount, instructorAccount, cadetAccount];

  final List<Account> accounts;
  final registered = <String>[];
  Account? _current;

  AuthResult _result(Account a) => AuthResult(
        token: fakeJwt(),
        user: AppUser(id: a.id, email: a.email, name: a.name, role: a.role),
      );

  @override
  Future<AuthResult> login(String email, String password) async {
    final found = accounts.where((a) => a.email == email);
    if (found.isEmpty || found.first.password != password) {
      throw const UnauthorizedException('Неверная почта или пароль.');
    }
    _current = found.first;
    return _result(_current!);
  }

  @override
  Future<void> register({
    required String email,
    required String password,
    required String name,
  }) async {
    if (accounts.any((a) => a.email == email)) {
      throw const ValidationException('Проверьте значения полей формы.',
          {'email': 'Такая почта уже занята'});
    }
    registered.add(email);
    accounts.add(
        Account(email, password, Role.cadet, name, 'u_${accounts.length}'));
  }

  @override
  Future<AuthResult> refresh() async => _result(_current ?? adminAccount);

  @override
  Future<String?> profileId(AppUser user) async =>
      accounts.where((a) => a.id == user.id).firstOrNull?.profileId;
}

String _day(int offsetDays, int hour) {
  final d = DateTime.now().add(Duration(days: offsetDays));
  return toPbDateTime(DateTime(d.year, d.month, d.day, hour));
}

InMemoryRepository makeSchoolRepository({
  void Function(String op, String collection, Map<String, dynamic> body)?
      validator,
}) {
  return InMemoryRepository(
    relations: relationMap(),
    validator: validator,
    data: {
      'categories': [
        {
          'id': 'catB',
          'code': 'B',
          'title': 'Легковой автомобиль',
          'min_age': 18,
          'theory_hours': 130,
          'practice_hours': 56,
          'price': 38000,
        },
        {
          'id': 'catA',
          'code': 'A',
          'title': 'Мотоцикл',
          'min_age': 16,
          'theory_hours': 100,
          'practice_hours': 18,
          'price': 22000,
        },
      ],
      'users': [
        for (final a in [adminAccount, instructorAccount, cadetAccount])
          {'id': a.id, 'email': a.email, 'name': a.name, 'role': a.role.name}
      ],
      'instructors': [
        {
          'id': 'i1',
          'user': 'u_instr',
          'full_name': 'Кузнецов Андрей Сергеевич',
          'phone': '+79991112233',
          'experience_years': 8,
          'license_no': '77АА123456',
          'categories': ['catB'],
          'hired_at': '2018-03-01 00:00:00.000Z',
        }
      ],
      'cars': [
        {
          'id': 'c1',
          'plate': 'А123ВС77',
          'model': 'Lada Granta',
          'year': 2022,
          'category': 'catB',
          'transmission': 'manual',
          'mileage': 41000,
          'status': 'active',
        }
      ],
      'cadets': [
        {
          'id': 'k1',
          'user': 'u_cadet',
          'full_name': 'Иванова Мария Петровна',
          'birth_date': '2002-04-09 00:00:00.000Z',
          'phone': '+79995556677',
          'category': 'catB',
          'status': 'studying',
          'enrolled_at': '2026-02-01 00:00:00.000Z',
        },
        {
          'id': 'k2',
          'full_name': 'Петров Пётр Сергеевич',
          'birth_date': '2001-11-23 00:00:00.000Z',
          'phone': '+79990001122',
          'category': 'catB',
          'status': 'studying',
          'enrolled_at': '2026-03-01 00:00:00.000Z',
        },
        {
          'id': 'k3',
          'full_name': 'Сидорова Анна Ильинична',
          'birth_date': '1999-01-15 00:00:00.000Z',
          'phone': '+79990003344',
          'category': 'catA',
          'status': 'graduated',
          'enrolled_at': '2025-09-01 00:00:00.000Z',
        },
      ],
      'medical_certificates': [
        {
          'id': 'm1',
          'cadet': 'k1',
          'number': '77-123456',
          'issued_at': '2026-01-10 00:00:00.000Z',
          'valid_until': '2029-01-10 00:00:00.000Z',
          'clinic': 'Поликлиника №1',
        }
      ],
      'lessons': [
        {
          'id': 'l1',
          'cadet': 'k1',
          'instructor': 'i1',
          'car': 'c1',
          'kind': 'city',
          'status': 'planned',
          'starts_at': _day(1, 10),
          'ends_at': _day(1, 11),
        },
        {
          'id': 'l2',
          'cadet': 'k1',
          'instructor': 'i1',
          'car': 'c1',
          'kind': 'ground',
          'status': 'done',
          'starts_at': _day(-3, 10),
          'ends_at': _day(-3, 11),
        },
      ],
      'groups': [
        {
          'id': 'g1',
          'name': 'Группа B-26-01',
          'category': 'catB',
          'curator': 'i1',
          'starts_at': '2026-02-01 00:00:00.000Z',
          'ends_at': '2026-08-01 00:00:00.000Z',
          'cadets': ['k1', 'k2'],
        }
      ],
      'exams': [
        {
          'id': 'e1',
          'cadet': 'k1',
          'type': 'theory',
          'exam_date': '2026-04-10 00:00:00.000Z',
          'result': 'passed',
          'score': 19,
          'attempt': 1,
        }
      ],
      'payments': [
        {
          'id': 'p1',
          'cadet': 'k1',
          'amount': 20000,
          'paid_at': '2026-02-02 00:00:00.000Z',
          'method': 'card',
          'purpose': 'tuition',
        }
      ],
    },
  );
}

Future<void> settle(WidgetTester tester, [String where = '']) async {
  try {
    await tester.pumpAndSettle(const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate, const Duration(seconds: 20));
  } catch (e) {
    throw StateError('Экран не успокоился $where: $e');
  }
}

class Harness {
  Harness(this.tester, this.repo, this.auth, this.connection);

  final WidgetTester tester;
  final RecordRepository repo;
  final AuthNotifier auth;
  final ConnectionNotifier connection;

  GoRouter get router =>
      GoRouter.of(tester.element(find.byType(Scaffold).first));

  String get location => router.routeInformationProvider.value.uri.toString();

  Future<void> go(String location) async {
    router.go(location);
    await settle(tester, 'на $location');
  }

  Future<void> close() async {
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
    connection.dispose();
  }
}

Future<Harness> pumpSchool(
  WidgetTester tester, {
  Role? role,
  Account? account,
  Size size = const Size(1280, 800),
  RecordRepository? repository,
  FakeAuthApi? authApi,
  String? location,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);

  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  final session = ApiSession();
  final api = authApi ?? FakeAuthApi();
  final repo = repository ?? makeSchoolRepository();
  final connection = ConnectionNotifier();
  final who = account ?? (role == null ? null : accountFor(role));

  if (who != null) {
    if (!api.accounts.contains(who)) api.accounts.add(who);
    await tester.runAsync(() async {
      final first = AuthNotifier(prefs, api, session);
      await first.login(who.email, who.password);
      first.dispose();
    });
  }

  final app = await tester.runAsync(() => buildApp(
        prefs: prefs,
        repository: repo,
        authApi: api,
        session: session,
        connection: connection,
      ));
  await tester.pumpWidget(app!);
  await settle(tester, 'при запуске');
  final auth = tester.element(find.byType(MaterialApp)).read<AuthNotifier>();
  final harness = Harness(tester, repo, auth, connection);
  if (location != null) await harness.go(location);
  return harness;
}
