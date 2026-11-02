import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../domain/entities.dart';
import '../domain/entity_def.dart';
import '../forms/dynamic_form.dart' show confirmLeave;
import '../screens/app_shell.dart';
import '../screens/auth_screens.dart';
import '../screens/book_lesson_screen.dart';
import '../screens/complete_profile_screen.dart';
import '../screens/entity_details_screen.dart';
import '../screens/entity_form_screen.dart';
import '../screens/entity_list_screen.dart';
import '../screens/forbidden_screen.dart';
import '../screens/home_screen.dart';
import '../screens/not_found_screen.dart';
import '../screens/progress_screen.dart';
import '../screens/report_screen.dart';
import '../screens/schedule_screen.dart';
import '../state/form_guard.dart';
import 'locations.dart';

Future<bool> _confirmExit(BuildContext context, GoRouterState state) async {
  final guard = context.read<UnsavedChangesGuard>();
  if (!guard.dirty) return true;
  final leave = await confirmLeave(context);
  if (leave) guard.dirty = false;
  return leave;
}

class RouteGuard {
  RouteGuard(this.auth);

  final AuthNotifier auth;

  String _forbidden(GoRouterState state, String need) => Uri(
        path: forbiddenPath,
        queryParameters: {'from': state.uri.toString(), 'need': need},
      ).toString();

  String? entity(GoRouterState state, EntityDef def, EntityOp op) {
    if (auth.canOn(def.collection, op)) return null;
    return _forbidden(state, '${op.label}: ${def.plural}');
  }

  String? permission(GoRouterState state, Permission permission) {
    if (auth.has(permission)) return null;
    return _forbidden(state, permission.label);
  }

  String? list(GoRouterState state, EntityDef def) {
    final denied = entity(state, def, EntityOp.view);
    if (denied != null) return denied;
    final params = state.uri.queryParameters;
    if (params.containsKey('deleted') &&
        !auth.canOn(def.collection, EntityOp.viewDeleted)) {
      final rest = Map.of(params)..remove('deleted');
      return Uri(
              path: state.uri.path, queryParameters: rest.isEmpty ? null : rest)
          .toString();
    }
    return null;
  }
}

String? safeFrom(String? from) {
  if (from == null || !from.startsWith('/') || from.startsWith('//')) {
    return null;
  }
  final path = Uri.tryParse(from)?.path;
  if (path == null ||
      path == loginPath ||
      path == registerPath ||
      path == completeProfilePath) {
    return null;
  }
  return from;
}

List<RouteBase> entityRoutes(RouteGuard guard, EntityDef def) => [
      GoRoute(
        path: def.path,
        redirect: (context, state) => guard.list(state, def),
        pageBuilder: (context, state) => NoTransitionPage(
          key: ValueKey('${def.path}-list'),
          child: EntityListScreen(def: def, params: state.uri.queryParameters),
        ),
      ),
      GoRoute(
        path: newLocation(def.path),
        redirect: (context, state) => guard.entity(state, def, EntityOp.create),
        onExit: _confirmExit,
        builder: (context, state) => EntityFormScreen(def: def),
      ),
      GoRoute(
        path: '${def.path}/:id',
        redirect: (context, state) => guard.entity(state, def, EntityOp.view),
        builder: (context, state) => EntityDetailsScreen(
          key: ValueKey(state.uri.path),
          def: def,
          id: state.pathParameters['id']!,
        ),
      ),
      GoRoute(
        path: '${def.path}/:id/edit',
        redirect: (context, state) => guard.entity(state, def, EntityOp.edit),
        onExit: _confirmExit,
        builder: (context, state) => EntityFormScreen(
          key: ValueKey(state.uri.path),
          def: def,
          id: state.pathParameters['id']!,
        ),
      ),
    ];

GoRoute _page(RouteGuard guard, String path, Permission permission,
        Widget Function(GoRouterState state) screen) =>
    GoRoute(
      path: path,
      redirect: (context, state) => guard.permission(state, permission),
      pageBuilder: (context, state) =>
          NoTransitionPage(key: ValueKey(path), child: screen(state)),
    );

GoRouter createRouter(AuthNotifier auth, {String initialLocation = homePath}) {
  final guard = RouteGuard(auth);
  return GoRouter(
    initialLocation: initialLocation,
    refreshListenable: auth,
    errorBuilder: (context, state) =>
        NotFoundScreen(location: state.uri.toString()),
    redirect: (context, state) {
      final loggedIn = auth.isAuthenticated;
      final path = state.uri.path;
      final isPublic = path == loginPath || path == registerPath;

      if (!loggedIn && !isPublic) {
        final from = state.uri.toString();
        if (auth.lastLogout == LogoutReason.manual || from == homePath) {
          return loginPath;
        }
        return Uri(path: loginPath, queryParameters: {'from': from}).toString();
      }

      if (loggedIn && auth.needsCadetProfile) {
        return path == completeProfilePath ? null : completeProfilePath;
      }
      if (loggedIn && path == completeProfilePath) return homePath;

      if (loggedIn && isPublic) {
        return safeFrom(state.uri.queryParameters['from']) ?? homePath;
      }
      return null;
    },
    routes: [
      GoRoute(
        path: loginPath,
        builder: (context, state) =>
            LoginScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: registerPath,
        builder: (context, state) =>
            RegisterScreen(from: state.uri.queryParameters['from']),
      ),
      GoRoute(
        path: completeProfilePath,
        builder: (context, state) => const CompleteProfileScreen(),
      ),
      ShellRoute(
        builder: (context, state, child) =>
            AppShell(location: state.uri.path, child: child),
        routes: [
          GoRoute(
            path: homePath,
            pageBuilder: (context, state) => const NoTransitionPage(
                key: ValueKey('home'), child: HomeScreen()),
          ),
          GoRoute(
            path: forbiddenPath,
            pageBuilder: (context, state) => NoTransitionPage(
              key: ValueKey(state.uri.toString()),
              child: ForbiddenScreen(
                from: state.uri.queryParameters['from'],
                need: state.uri.queryParameters['need'],
              ),
            ),
          ),
          _page(guard, schedulePath, Permission.viewSchedule,
              (s) => ScheduleScreen(params: s.uri.queryParameters)),
          _page(guard, bookPath, Permission.bookLesson,
              (s) => const BookLessonScreen()),
          _page(guard, progressPath, Permission.viewProgress,
              (s) => const ProgressScreen()),
          GoRoute(
            path: '$progressPath/:id',
            redirect: (context, state) {
              final denied = guard.permission(state, Permission.viewProgress);
              if (denied != null) return denied;
              return auth.role == Role.cadet ? progressPath : null;
            },
            pageBuilder: (context, state) => NoTransitionPage(
              key: ValueKey(state.uri.path),
              child: ProgressScreen(cadetId: state.pathParameters['id']),
            ),
          ),
          _page(guard, reportPath, Permission.viewReport,
              (s) => const ReportScreen()),
          for (final def in entityDefs.values) ...entityRoutes(guard, def),
        ],
      ),
    ],
  );
}
