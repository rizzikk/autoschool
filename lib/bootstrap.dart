import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'auth/auth_api.dart';
import 'auth/auth_notifier.dart';
import 'core/api_client.dart';
import 'core/config.dart';
import 'core/connection.dart';
import 'core/session.dart';
import 'repositories/pocketbase_repository.dart';
import 'repositories/record_repository.dart';
import 'state/form_guard.dart';
import 'state/relation_options.dart';

Future<Widget> buildApp({
  required SharedPreferences prefs,
  Dio? dio,
  RecordRepository? repository,
  AuthApi? authApi,
  ApiSession? session,
  ConnectionNotifier? connection,
  SessionPolicy policy = SessionPolicy.fromEnvironment,
  String initialLocation = '/',
}) async {
  final apiSession = session ?? ApiSession();

  Dio? client = dio;

  final link = connection ??
      ConnectionNotifier(probe: () async {
        final http = client;
        if (http == null) return true;
        try {
          await http.get<dynamic>('/health',
              options: Options(extra: {'skipAuth': true}));
          return true;
        } on DioException catch (e) {
          return e.response != null;
        }
      });
  Dio network() => client ??= buildDio(apiSession, connection: link);

  final auth = AuthNotifier(prefs, authApi ?? AuthApi(network()), apiSession,
      policy: policy);
  await auth.restore();

  final records = repository ?? PocketBaseRepository(network());

  return MultiProvider(
    providers: [
      ChangeNotifierProvider<ConnectionNotifier>.value(value: link),
      ChangeNotifierProvider<AuthNotifier>.value(value: auth),
      Provider<RecordRepository>.value(value: records),
      Provider<RelationOptions>(create: (_) => RelationOptions(records)),
      Provider<UnsavedChangesGuard>(create: (_) => UnsavedChangesGuard()),
    ],
    child: AutoschoolApp(initialLocation: initialLocation),
  );
}
