import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../core/breakpoints.dart';
import '../domain/entities.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../state/details_notifier.dart';
import '../util/format.dart';
import '../widgets/state_views.dart';

class HomeData {
  const HomeData({
    this.lessons = const [],
    this.counters = const [],
    this.lessonsTitle = '',
    this.lessonsEmpty = '',
  });

  final List<PbRecord> lessons;
  final String lessonsTitle;
  final String lessonsEmpty;

  final List<({String label, int value, IconData icon})> counters;
}

Future<HomeData> loadHomeData(
    RecordRepository repo, AuthNotifier auth, DateTime now) async {
  final user = auth.user;
  if (user == null) return const HomeData();
  const notDeleted = Eq('deleted', false);
  switch (user.role) {
    case Role.cadet:
      final id = user.profileId;
      if (id == null) return const HomeData();
      final page = await repo.list(
        'lessons',
        perPage: 5,
        where: And([
          Eq('cadet', id),
          const Eq('status', 'planned'),
          Gte('starts_at', toPbDateTime(now)),
          notDeleted,
        ]),
        sort: 'starts_at',
        expand: 'instructor,car',
      );
      return HomeData(
        lessons: page.items,
        lessonsTitle: 'Ближайшие занятия',
        lessonsEmpty: 'Запланированных занятий нет. '
            'Запишитесь на вождение — выберите инструктора и время.',
      );
    case Role.instructor:
      final id = user.profileId;
      if (id == null) return const HomeData();
      final today = dayStart(now);
      final page = await repo.list(
        'lessons',
        perPage: 20,
        where: And([
          Eq('instructor', id),
          Gte('starts_at', toPbDateTime(today)),
          Lte('starts_at', toPbDateTime(today.add(const Duration(days: 1)))),
          notDeleted,
        ]),
        sort: 'starts_at',
        expand: 'cadet,car',
      );
      return HomeData(
        lessons: page.items,
        lessonsTitle: 'Занятия на сегодня',
        lessonsEmpty: 'На сегодня занятий нет.',
      );
    case Role.admin:
      final weekEnd = dayStart(now).add(const Duration(days: 7));
      Future<int> total(String collection, Cond where) async =>
          (await repo.list(collection, perPage: 1, where: where)).total;
      final r = await Future.wait([
        total('cadets', const And([Eq('status', 'studying'), notDeleted])),
        total(
            'lessons',
            And([
              const Eq('status', 'planned'),
              Gte('starts_at', toPbDateTime(now)),
              Lte('starts_at', toPbDateTime(weekEnd)),
              notDeleted,
            ])),
        total('instructors', notDeleted),
        total('cars', const And([Eq('status', 'active'), notDeleted])),
      ]);
      return HomeData(counters: [
        (label: 'Курсантов обучается', value: r[0], icon: Icons.school),
        (
          label: 'Занятий на ближайшие 7 дней',
          value: r[1],
          icon: Icons.event_available
        ),
        (label: 'Инструкторов', value: r[2], icon: Icons.badge_outlined),
        (
          label: 'Автомобилей в эксплуатации',
          value: r[3],
          icon: Icons.directions_car
        ),
      ]);
  }
}

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user;
    if (user == null) return const SizedBox.shrink();
    return ChangeNotifierProvider(
      key: ValueKey('${user.id}-${user.profileId}'),
      create: (context) => DetailsNotifier<HomeData>(() =>
          loadHomeData(context.read<RecordRepository>(), auth, DateTime.now()))
        ..load(),
      child: Consumer<DetailsNotifier<HomeData>>(
        builder: (context, n, _) => DetailsStateView(
          status: n.status,
          error: n.error,
          notFound: false,
          hasData: n.data != null,
          notFoundMessage: '',
          onRetry: n.load,
          builder: () => _HomeView(data: n.data!),
        ),
      ),
    );
  }
}

class _HomeView extends StatelessWidget {
  const _HomeView({required this.data});

  final HomeData data;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final user = auth.user!;
    final theme = Theme.of(context);
    final wide = screenSizeOf(context) != ScreenSize.compact;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Здравствуйте, ${user.displayName}',
            style: theme.textTheme.headlineSmall),
        const SizedBox(height: 4),
        Text('Роль: ${user.role.label}', style: theme.textTheme.bodyMedium),
        const SizedBox(height: 16),
        if (auth.role == Role.admin && data.counters.isNotEmpty) ...[
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              for (final c in data.counters)
                SizedBox(
                  width: wide ? 260 : double.infinity,
                  child: Card(
                    child: ListTile(
                      leading: Icon(c.icon, color: theme.colorScheme.primary),
                      title: Text('${c.value}',
                          style: theme.textTheme.headlineSmall),
                      subtitle: Text(c.label),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
        ],
        if (data.lessonsTitle.isNotEmpty) ...[
          Text(data.lessonsTitle, style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          if (data.lessons.isEmpty)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(data.lessonsEmpty),
              ),
            )
          else
            Card(
              child: Column(
                children: [
                  for (final l in data.lessons) _LessonTile(lesson: l),
                ],
              ),
            ),
          const SizedBox(height: 16),
        ],
        Text('Быстрые действия', style: theme.textTheme.titleMedium),
        const SizedBox(height: 8),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final s in _quickLinks(auth))
              FilledButton.tonalIcon(
                onPressed: () => context.go(s.path),
                icon: Icon(s.icon),
                label: Text(s.label),
              ),
          ],
        ),
      ],
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile({required this.lesson});

  final PbRecord lesson;

  @override
  Widget build(BuildContext context) {
    final start = lesson.dateTime('starts_at');
    final end = lesson.dateTime('ends_at');
    final who = lesson.one('instructor') ?? lesson.one('cadet');
    final car = lesson.one('car');
    return ListTile(
      leading: const Icon(Icons.event),
      title: Text(start == null
          ? '—'
          : '${fmtDate(start)}, ${fmtTime(start)}'
              '${end == null ? '' : '–${fmtTime(end)}'}'),
      subtitle: Text([
        if (who != null) who.str('full_name'),
        if (car != null) '${car.str('model')} ${car.str('plate')}',
      ].join(' · ')),
      trailing: Text(lessonStatuses[lesson.str('status')] ?? ''),
    );
  }
}

List<({String path, IconData icon, String label})> _quickLinks(
    AuthNotifier auth) {
  final all = <({String path, IconData icon, String label, bool allowed})>[
    (
      path: bookPath,
      icon: Icons.edit_calendar,
      label: 'Записаться на вождение',
      allowed: auth.has(Permission.bookLesson)
    ),
    (
      path: schedulePath,
      icon: Icons.calendar_month,
      label: 'Расписание',
      allowed: auth.has(Permission.viewSchedule)
    ),
    (
      path: progressPath,
      icon: Icons.trending_up,
      label: auth.role == Role.cadet ? 'Мой прогресс' : 'Прогресс курсантов',
      allowed: auth.has(Permission.viewProgress)
    ),
    (
      path: '/cadets',
      icon: Icons.school,
      label: 'Курсанты',
      allowed: auth.role != Role.cadet && auth.canOn('cadets', EntityOp.view)
    ),
    (
      path: '/payments',
      icon: Icons.payments_outlined,
      label: auth.role == Role.cadet ? 'Мои платежи' : 'Платежи',
      allowed: auth.canOn('payments', EntityOp.view)
    ),
    (
      path: reportPath,
      icon: Icons.insights,
      label: 'Отчёт',
      allowed: auth.has(Permission.viewReport)
    ),
  ];
  return [
    for (final l in all)
      if (l.allowed) (path: l.path, icon: l.icon, label: l.label),
  ];
}
