import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../core/api_exceptions.dart';
import '../domain/entities.dart';
import '../domain/lesson_rules.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../util/format.dart';
import '../widgets/dialogs.dart';
import '../widgets/state_views.dart';

const bookingDayStartHour = 8;
const bookingDayEndHour = 20;

List<DateTime> candidateStarts(DateTime day, int minutes) {
  final result = <DateTime>[];
  final first = DateTime(day.year, day.month, day.day, bookingDayStartHour);
  final lastEnd = DateTime(day.year, day.month, day.day, bookingDayEndHour);
  for (var s = first;
      !s.add(Duration(minutes: minutes)).isAfter(lastEnd);
      s = s.add(const Duration(minutes: 30))) {
    result.add(s);
  }
  return result;
}

String? slotUnavailableReason({
  required DateTime start,
  required int minutes,
  required List<BusySlot> busy,
  required String instructor,
  required String car,
  required String cadet,
  required DateTime now,
}) {
  if (!start.isAfter(now.add(const Duration(minutes: 30)))) {
    return 'Это время уже прошло или слишком скоро';
  }
  final conflicts = findBusyConflicts(busy,
      start: start,
      end: start.add(Duration(minutes: minutes)),
      instructor: instructor,
      car: car,
      cadet: cadet);
  if (conflicts.containsKey('cadet')) return 'У вас в это время другое занятие';
  if (conflicts.containsKey('instructor')) return 'Инструктор занят';
  if (conflicts.containsKey('car')) return 'Автомобиль занят';
  return null;
}

class BookLessonScreen extends StatefulWidget {
  const BookLessonScreen({super.key});

  @override
  State<BookLessonScreen> createState() => _BookLessonScreenState();
}

class _BookLessonScreenState extends State<BookLessonScreen> {
  late final RecordRepository _repo;
  PbRecord? _cadet;
  List<PbRecord> _instructors = const [];
  List<PbRecord> _cars = const [];
  List<PbRecord> _certs = const [];
  List<BusySlot> _busy = const [];
  bool _loading = true;
  bool _busyLoading = false;
  bool _saving = false;
  String? _error;
  String? _noProfile;

  late DateTime _day;
  String? _instructor;
  String? _car;
  int _minutes = 90;
  String _kind = 'city';
  DateTime? _slot;
  int _busyRequest = 0;

  @override
  void initState() {
    super.initState();
    _repo = context.read<RecordRepository>();
    final now = DateTime.now();
    _day = DateTime(now.year, now.month, now.day + 1);
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final profile = context.read<AuthNotifier>().user?.profileId;
      if (profile == null) {
        _noProfile = 'Сначала заполните анкету курсанта.';
        setState(() => _loading = false);
        return;
      }
      final cadet = await _repo.find('cadets', profile, expand: 'category');
      if (cadet == null) {
        _noProfile = 'Анкета курсанта не найдена.';
        setState(() => _loading = false);
        return;
      }
      final category = cadet.rel('category');
      final results = await Future.wait([
        _repo.listAll('instructors',
            where:
                And([Has('categories', category), const Eq('deleted', false)]),
            sort: 'full_name'),
        _repo.listAll('cars',
            where: And([
              Eq('category', category),
              const Eq('status', 'active'),
              const Eq('deleted', false)
            ]),
            sort: 'plate'),
        _repo.listAll('medical_certificates',
            where: And([Eq('cadet', cadet.id), const Eq('deleted', false)])),
      ]);
      if (!mounted) return;
      setState(() {
        _cadet = cadet;
        _instructors = results[0];
        _cars = results[1];
        _certs = results[2];
        _instructor = _instructors.isEmpty ? null : _instructors.first.id;
        _car = _cars.isEmpty ? null : _cars.first.id;
        _loading = false;
      });
      await _loadBusy();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = 'Не удалось загрузить данные для записи: $e';
        _loading = false;
      });
    }
  }

  Future<void> _loadBusy() async {
    final cadet = _cadet;
    if (cadet == null || _instructor == null || _car == null) return;
    final request = ++_busyRequest;
    setState(() => _busyLoading = true);
    try {
      final slots = await _repo.busy(
        from: _day,
        to: DateTime(_day.year, _day.month, _day.day + 1),
        instructor: _instructor,
        car: _car,
        cadet: cadet.id,
      );
      if (request != _busyRequest || !mounted) return;
      setState(() {
        _busy = slots;
        _busyLoading = false;
      });
    } catch (e) {
      if (request != _busyRequest || !mounted) return;
      setState(() => _busyLoading = false);
      await showApiError(context, e, prefix: 'Не удалось получить занятость');
    }
  }

  bool get _medicalOk => _certs.any((c) => medicalValidOn(c, _day));

  Future<void> _book() async {
    final cadet = _cadet, slot = _slot;
    if (cadet == null || slot == null || _instructor == null || _car == null) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _saving = true);
    try {
      await _repo.create('lessons', {
        'cadet': cadet.id,
        'instructor': _instructor,
        'car': _car,
        'starts_at': toPbDateTime(slot),
        'ends_at': toPbDateTime(slot.add(Duration(minutes: _minutes))),
        'kind': _kind,
        'status': 'planned',
        'deleted': false,
      });
      if (!mounted) return;
      messenger.showSnackBar(
          SnackBar(content: Text('Вы записаны на ${fmtDateTime(slot)}')));
      final monday = weekStart(slot);
      context.go(Uri(path: schedulePath, queryParameters: {
        'week': '${monday.year}-${two(monday.month)}-${two(monday.day)}',
      }).toString());
    } on ConflictException catch (e) {
      messenger.showSnackBar(SnackBar(content: Text(e.message)));
      setState(() => _slot = null);
      await _loadBusy();
    } on ValidationException catch (e) {
      messenger.showSnackBar(SnackBar(
          content:
              Text(e.errors.isEmpty ? e.message : e.errors.values.join('\n'))));
    } catch (e) {
      if (mounted) {
        await showApiError(context, e,
            prefix: 'Не удалось записаться', messenger: messenger);
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const LoadingView();
    if (_error != null) return ErrorView(message: _error!, onRetry: _load);
    if (_noProfile != null) {
      return MessageView(
        icon: Icons.person_search,
        title: 'Запись недоступна',
        message: _noProfile!,
      );
    }
    final theme = Theme.of(context);
    final category = _cadet!.one('category');
    final noResources = _instructors.isEmpty || _cars.isEmpty;
    final now = DateTime.now();
    final starts = candidateStarts(_day, _minutes);
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  Icon(Icons.edit_calendar, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text('Запись на вождение',
                        style: theme.textTheme.headlineSmall),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Категория ${category?.str('code') ?? ''}: показаны инструкторы и '
                'автомобили вашей категории.',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              if (noResources)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('Для вашей категории сейчас нет доступных '
                        'инструкторов или автомобилей. Обратитесь в администрацию.'),
                  ),
                )
              else ...[
                _daySelector(context),
                const SizedBox(height: 16),
                Wrap(
                  spacing: 16,
                  runSpacing: 16,
                  children: [
                    _dropdown(
                      label: 'Инструктор',
                      value: _instructor,
                      items: {
                        for (final i in _instructors) i.id: i.str('full_name')
                      },
                      onChanged: (v) {
                        setState(() {
                          _instructor = v;
                          _slot = null;
                        });
                        _loadBusy();
                      },
                    ),
                    _dropdown(
                      label: 'Автомобиль',
                      value: _car,
                      items: {
                        for (final c in _cars)
                          c.id: '${c.str('plate')} · ${c.str('model')}',
                      },
                      onChanged: (v) {
                        setState(() {
                          _car = v;
                          _slot = null;
                        });
                        _loadBusy();
                      },
                    ),
                    _dropdown(
                      label: 'Длительность',
                      value: '$_minutes',
                      items: const {
                        '60': '1 час',
                        '90': '1,5 часа',
                        '120': '2 часа',
                      },
                      onChanged: (v) => setState(() {
                        _minutes = int.parse(v!);
                        _slot = null;
                      }),
                    ),
                    _dropdown(
                      label: 'Тип занятия',
                      value: _kind,
                      items: lessonKinds,
                      onChanged: (v) => setState(() => _kind = v!),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (!_medicalOk)
                  Card(
                    color: theme.colorScheme.errorContainer,
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Icon(Icons.medical_services_outlined,
                              color: theme.colorScheme.onErrorContainer),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'На ${fmtDate(_day)} у вас нет действующей медицинской '
                              'справки: записаться на эту дату нельзя.',
                              style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Text('Время начала на ${fmtDate(_day)}',
                        style: theme.textTheme.titleMedium),
                    const SizedBox(width: 12),
                    if (_busyLoading)
                      const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(strokeWidth: 2)),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    for (final s in starts) _slotChip(context, s, now),
                  ],
                ),
                const SizedBox(height: 8),
                Text('Серым отмечено время, которое занято или уже прошло.',
                    style: theme.textTheme.bodySmall),
                const SizedBox(height: 20),
                FilledButton.icon(
                  onPressed:
                      _slot == null || _saving || !_medicalOk ? null : _book,
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(_slot == null
                      ? 'Выберите время'
                      : 'Записаться на ${fmtTime(_slot!)}–'
                          '${fmtTime(_slot!.add(Duration(minutes: _minutes)))}'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _slotChip(BuildContext context, DateTime start, DateTime now) {
    final reason = slotUnavailableReason(
      start: start,
      minutes: _minutes,
      busy: _busy,
      instructor: _instructor ?? '',
      car: _car ?? '',
      cadet: _cadet!.id,
      now: now,
    );
    final chip = ChoiceChip(
      label: Text(fmtTime(start)),
      selected: _slot == start,
      onSelected: reason != null ? null : (_) => setState(() => _slot = start),
    );
    return reason == null ? chip : Tooltip(message: reason, child: chip);
  }

  Widget _dropdown({
    required String label,
    required String? value,
    required Map<String, String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return SizedBox(
      width: 250,
      child: DropdownButtonFormField<String>(
        initialValue: items.containsKey(value) ? value : null,
        isExpanded: true,
        decoration: InputDecoration(
          labelText: label,
          border: const OutlineInputBorder(),
        ),
        items: [
          for (final e in items.entries)
            DropdownMenuItem(
                value: e.key,
                child: Text(e.value, overflow: TextOverflow.ellipsis)),
        ],
        onChanged: onChanged,
      ),
    );
  }

  Widget _daySelector(BuildContext context) {
    final today = dayStart(DateTime.now());
    final days = List.generate(
        21, (i) => DateTime(today.year, today.month, today.day + i));
    return SizedBox(
      height: 72,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: days.length,
        separatorBuilder: (_, __) => const SizedBox(width: 8),
        itemBuilder: (context, i) {
          final d = days[i];
          final selected = d == _day;
          final scheme = Theme.of(context).colorScheme;
          return InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              setState(() {
                _day = d;
                _slot = null;
              });
              _loadBusy();
            },
            child: Container(
              width: 62,
              decoration: BoxDecoration(
                color:
                    selected ? scheme.primary : scheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(weekdayShort[d.weekday - 1],
                      style: TextStyle(
                          color: selected
                              ? scheme.onPrimary
                              : scheme.onSurfaceVariant)),
                  Text('${d.day}',
                      style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w600,
                          color:
                              selected ? scheme.onPrimary : scheme.onSurface)),
                ],
              ),
            ),
          );
        },
      ),
    );
  }
}
