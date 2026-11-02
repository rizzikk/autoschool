import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import 'auth/auth_notifier.dart';
import 'core/connection.dart';
import 'router/app_router.dart';
import 'state/relation_options.dart';
import 'widgets/connection_banner.dart';
import 'widgets/inactivity_watcher.dart';

class AutoschoolApp extends StatefulWidget {
  const AutoschoolApp({super.key, this.initialLocation = '/'});

  final String initialLocation;

  @override
  State<AutoschoolApp> createState() => _AutoschoolAppState();
}

class _AutoschoolAppState extends State<AutoschoolApp> {
  late final GoRouter _router;
  final _messenger = GlobalKey<ScaffoldMessengerState>();
  AuthNotifier? _auth;
  int _recoveries = 0;
  ConnectionNotifier? _connection;
  String? _lastUserId;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthNotifier>();
    _router = createRouter(auth, initialLocation: widget.initialLocation);
    _auth = auth..addListener(_onAuthChanged);
    _lastUserId = auth.user?.id;
    final connection = context.read<ConnectionNotifier>();
    _connection = connection..addListener(_onConnectionChanged);
    _recoveries = connection.recoveries;
  }

  void _onAuthChanged() {
    final id = _auth?.user?.id;
    if (id != _lastUserId) {
      _lastUserId = id;
      context.read<RelationOptions>().invalidate();
    }
  }

  void _onConnectionChanged() {
    final c = _connection;
    if (c != null && c.recoveries != _recoveries) {
      _recoveries = c.recoveries;
      context.read<RelationOptions>().invalidate();
    }
  }

  @override
  void dispose() {
    _auth?.removeListener(_onAuthChanged);
    _connection?.removeListener(_onConnectionChanged);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Автошкола',
      debugShowCheckedModeBanner: false,
      scaffoldMessengerKey: _messenger,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF00796B),
        useMaterial3: true,
      ),
      locale: const Locale('ru'),
      supportedLocales: const [Locale('ru')],
      localizationsDelegates: GlobalMaterialLocalizations.delegates,
      routerConfig: _router,
      builder: (context, child) {
        final auth = context.watch<AuthNotifier>();
        return InactivityWatcher(
          enabled: auth.isAuthenticated,
          timeout: auth.policy.idleTimeout,
          warning: auth.policy.idleWarning,
          onActivity: auth.touch,
          onTimeout: () => auth.logout(reason: LogoutReason.inactivity),
          child: Column(
            children: [
              ConnectionBanner(connection: context.read<ConnectionNotifier>()),
              Expanded(child: child ?? const SizedBox.shrink()),
            ],
          ),
        );
      },
    );
  }
}
