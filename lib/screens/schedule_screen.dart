import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../domain/entities.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../util/format.dart';
import '../widgets/dialogs.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/state_views.dart';

List<List<PbRecord>> groupLessonsByDay(
    List<PbRecord> lessons, DateTime monday) {
  final days = List.generate(7, (_) => <PbRecord>[]);
  for (final l in lessons) {
    final d = l.dateTime('starts_at');
    if (d == null) continue;
    final index = DateTime(d.year, d.month, d.day).difference(monday).inDays;
    if (index >= 0 && index < 7) days[index].add(l);
  }
  for (final day in days) {
    day.sort((a, b) => a.str('starts_at').compareTo(b.str('starts_at')));
  }
  return days;
}

class ScheduleScreen extends StatefulWidget {
  const ScheduleScreen({super.key, required this.params});

  final Map<String, String> params;

  @override
  State<ScheduleScreen> createState() => _ScheduleScreenState();
}

class _ScheduleScreenState extends State<ScheduleScreen> {
  late RecordRepository _repo;
  late DateTime _monday;
  String? _instructor;
  List<PbRecord> _lessons = const [];
  List<PbRecord> _instructors = const [];
  bool _loading = true;
  String? _error;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<RecordRepository>();
    _readParams();
    _load();
    if (context.read<AuthNotifier>().role == Role.admin) _loadInstructors();
  }

  void _readParams() {
    final w = DateTime.tryParse(widget.params['week'] ?? '');
    _monday = weekStart(w ?? DateTime.now());
    final i = widget.params['instructor'];
    _instructor = i == null || i.isEmpty ? null : i;
  }

  @override
  void didUpdateWidget(ScheduleScreen old) {
    super.didUpdateWidget(old);
    if (!mapEquals(old.params, widget.params)) {
      _readParams();
      _load();
    }
  }

  Future<void> _loadInstructors() async {
    try {
      final list = await _repo.listAll('instructors',
          where: const Eq('deleted', false), sort: 'full_name');
      if (mounted) setState(() => _instructors = list);
    } catch (_) {}
  }

  Future<void> _load() async {
    final request = ++_request;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final end = DateTime(_monday.year, _monday.month, _monday.day + 7);
      final list = await _repo.listAll(
        'lessons',
        where: allOf([
          const Eq('deleted', false),
          Gte('starts_at', toPbDateTime(_monday)),
          Lte('starts_at',
              toPbDateTime(end.subtract(const Duration(seconds: 1)))),
          if (_instructor != null) Eq('instructor', _instructor!),
        ]),
        sort: 'starts_at',
        expand: 'cadet,instructor,car',
      );
      if (request != _request || !mounted) return;
      setState(() {
        _lessons = list;
        _loading = false;
      });
    } catch (e) {
      if (request != _request || !mounted) return;
      setState(() {
        _error = 'Не удалось загрузить расписание: $e';
        _loading = false;
      });
    }
  }

  void _go({DateTime? week, Object? instructor = _keep}) {
    final target = week ?? _monday;
    final i =
        identical(instructor, _keep) ? _instructor : instructor as String?;
    final p = <String, String>{
      'week': '${target.year}-${two(target.month)}-${two(target.day)}',
      if (i != null && i.isNotEmpty) 'instructor': i,
    };
    context.go(Uri(path: schedulePath, queryParameters: p).toString());
  }

  static const _keep = Object();

  String _weekTitle() {
    final end = _monday.add(const Duration(days: 6));
    final sameMonth = end.month == _monday.month;
    final month = monthNames[end.month - 1];
    return sameMonth
        ? '${_monday.day}–${end.day} $month ${end.year}'
        : '${_monday.day} ${monthNames[_monday.month - 1]} – ${end.day} $month ${end.year}';
  }

  @override
  Widget build(BuildContext context) {
    final role = context.watch<AuthNotifier>().role;
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
          child: Row(
            children: [
              Icon(Icons.calendar_month, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text('Расписание', style: theme.textTheme.headlineSmall),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
          child: Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 4,
            runSpacing: 4,
            children: [
              IconButton(
                tooltip: 'Предыдущая неделя',
                icon: const Icon(Icons.chevron_left),
                onPressed: () =>
                    _go(week: _monday.subtract(const Duration(days: 7))),
              ),
              Text(_weekTitle(), style: theme.textTheme.titleMedium),
              IconButton(
                tooltip: 'Следующая неделя',
                icon: const Icon(Icons.chevron_right),
                onPressed: () => _go(
                    week:
                        DateTime(_monday.year, _monday.month, _monday.day + 7)),
              ),
              TextButton(
                onPressed: () => _go(week: weekStart(DateTime.now())),
                child: const Text('Сегодня'),
              ),
              if (role == Role.admin && _instructors.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(left: 12),
                  child: LabeledDropdown<String>(
                    label: 'Инструктор',
                    value: _instructor,
                    width: 230,
                    options: {
                      for (final i in _instructors) i.id: i.str('full_name'),
                    },
                    onChanged: (v) => _go(instructor: v),
                  ),
                ),
            ],
          ),
        ),
        Expanded(child: _content(context, role)),
      ],
    );
  }

  Widget _content(BuildContext context, Role? role) {
    if (_error != null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    if (_loading && _lessons.isEmpty) return const LoadingView();
    final days = groupLessonsByDay(_lessons, _monday);
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final today = dayStart(DateTime.now());
    Widget dayColumn(int i) => _DayColumn(
          date: DateTime(_monday.year, _monday.month, _monday.day + i),
          isToday:
              DateTime(_monday.year, _monday.month, _monday.day + i) == today,
          lessons: days[i],
          role: role,
          onTap: (l) => _showLesson(context, l, role),
        );
    return Column(
      children: [
        SizedBox(
            height: 3,
            child: _loading ? const LinearProgressIndicator() : null),
        Expanded(
          child: wide
              ? SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      for (var i = 0; i < 7; i++)
                        Expanded(
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 3),
                            child: dayColumn(i),
                          ),
                        ),
                    ],
                  ),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 16),
                  children: [for (var i = 0; i < 7; i++) dayColumn(i)],
                ),
        ),
      ],
    );
  }

  Future<void> _showLesson(BuildContext context, PbRecord l, Role? role) async {
    final repo = _repo;
    final def = lessonsDef;
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheet) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(def.titleOf(l),
                  style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                  'Инструктор: ${l.one('instructor')?.str('full_name') ?? '—'}'),
              Text('Автомобиль: ${l.one('car')?.str('plate') ?? '—'} '
                  '${l.one('car')?.str('model') ?? ''}'),
              Text('Тип: ${lessonKinds[l.str('kind')] ?? ''}'),
              Text('Статус: ${lessonStatuses[l.str('status')] ?? ''}'),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (role != null)
                    for (final a in def.actions)
                      if (a.visible(role, l))
                        FilledButton.tonalIcon(
                          icon: Icon(a.icon),
                          label: Text(a.label),
                          onPressed: () async {
                            Navigator.of(sheet).pop();
                            if (a.confirm != null) {
                              final ok = await confirmAction(context,
                                  title: a.label,
                                  message: a.confirm!,
                                  confirmLabel: 'Да',
                                  destructive: false);
                              if (!ok || !context.mounted) return;
                            }
                            final done = await runWithFeedback(
                                context, () => a.run(repo, l),
                                success: a.success);
                            if (done) await _load();
                          },
                        ),
                  OutlinedButton.icon(
                    icon: const Icon(Icons.open_in_new),
                    label: const Text('Открыть запись'),
                    onPressed: () {
                      Navigator.of(sheet).pop();
                      context.go(detailsLocation(def.path, l.id));
                    },
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _DayColumn extends StatelessWidget {
  const _DayColumn({
    required this.date,
    required this.isToday,
    required this.lessons,
    required this.role,
    required this.onTap,
  });

  final DateTime date;
  final bool isToday;
  final List<PbRecord> lessons;
  final Role? role;
  final void Function(PbRecord lesson) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: isToday ? scheme.primary : scheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              '${weekdayShort[date.weekday - 1]}, ${date.day} ${monthNames[date.month - 1].substring(0, 3)}'
              '${lessons.isEmpty ? '' : ' · ${lessons.length}'}',
              style: theme.textTheme.titleSmall?.copyWith(
                color: isToday ? scheme.onPrimary : scheme.onSurface,
              ),
            ),
          ),
          if (lessons.isEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 8, 10, 4),
              child: Text('Занятий нет',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.outline)),
            ),
          for (final l in lessons)
            _LessonTile(lesson: l, role: role, onTap: onTap),
        ],
      ),
    );
  }
}

class _LessonTile extends StatelessWidget {
  const _LessonTile(
      {required this.lesson, required this.role, required this.onTap});

  final PbRecord lesson;
  final Role? role;
  final void Function(PbRecord lesson) onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final status = lesson.str('status');
    final (bg, fg) = switch (status) {
      'done' => (scheme.tertiaryContainer, scheme.onTertiaryContainer),
      'cancelled' => (scheme.surfaceContainerHighest, scheme.outline),
      'no_show' => (scheme.errorContainer, scheme.onErrorContainer),
      _ => (scheme.primaryContainer, scheme.onPrimaryContainer),
    };
    final s = lesson.dateTime('starts_at'), e = lesson.dateTime('ends_at');
    final who = switch (role) {
      Role.cadet => lesson.one('instructor')?.str('full_name') ?? '',
      Role.instructor => lesson.one('cadet')?.str('full_name') ?? '',
      _ => '${lesson.one('cadet')?.str('full_name') ?? ''} · '
          '${lesson.one('instructor')?.str('full_name') ?? ''}',
    };
    final strike = status == 'cancelled' ? TextDecoration.lineThrough : null;
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(8),
        child: InkWell(
          borderRadius: BorderRadius.circular(8),
          onTap: () => onTap(lesson),
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  s == null || e == null ? '' : '${fmtTime(s)}–${fmtTime(e)}',
                  style: theme.textTheme.titleSmall
                      ?.copyWith(color: fg, decoration: strike),
                ),
                Text(who,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: theme.textTheme.bodySmall
                        ?.copyWith(color: fg, decoration: strike)),
                Text(
                  '${lesson.one('car')?.str('plate') ?? ''} · ${lessonStatuses[status] ?? status}',
                  style: theme.textTheme.bodySmall?.copyWith(color: fg),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
