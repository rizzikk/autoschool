import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../domain/entities.dart';
import '../domain/progress.dart';
import '../domain/report.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../state/details_notifier.dart';
import '../util/download.dart';
import '../util/format.dart';
import '../widgets/state_views.dart';

class ReportScreen extends StatefulWidget {
  const ReportScreen({super.key});

  @override
  State<ReportScreen> createState() => _ReportScreenState();
}

class _ReportScreenState extends State<ReportScreen> {
  int _days = 90;
  late DetailsNotifier<ReportData> _notifier;

  @override
  void initState() {
    super.initState();
    _notifier = _create();
  }

  DetailsNotifier<ReportData> _create() =>
      DetailsNotifier<ReportData>(_load)..load();

  (DateTime, DateTime) get _period {
    final today = dayStart(DateTime.now());
    return (
      DateTime(today.year, today.month, today.day - _days),
      DateTime(today.year, today.month, today.day + 1),
    );
  }

  Future<ReportData?> _load() async {
    final repo = context.read<RecordRepository>();
    final (from, to) = _period;
    final lessons = repo.listAll('lessons',
        where: And([
          const Eq('deleted', false),
          Gte('starts_at', toPbDateTime(from)),
          Lte('starts_at', toPbDateTime(to)),
        ]),
        expand: 'instructor');
    final payments = repo.listAll('payments',
        where: And([
          const Eq('deleted', false),
          Gte('paid_at', toPbDate(from)),
          Lte('paid_at', toPbDate(to)),
        ]));
    final exams = repo.listAll('exams',
        where: And([
          const Eq('deleted', false),
          Gte('exam_date', toPbDate(from)),
          Lte('exam_date', toPbDate(to)),
        ]));
    final cadets = repo.listAll('cadets', where: const Eq('deleted', false));
    final r = await Future.wait([lessons, payments, exams, cadets]);
    return buildReport(
      from: from,
      to: to.subtract(const Duration(days: 1)),
      lessons: r[0],
      payments: r[1],
      exams: r[2],
      cadets: r[3],
    );
  }

  void _setPeriod(int days) {
    if (days == _days) return;
    setState(() {
      _days = days;
      _notifier.dispose();
      _notifier = _create();
    });
  }

  Future<void> _export() async {
    final messenger = ScaffoldMessenger.of(context);
    final repo = context.read<RecordRepository>();
    final (from, to) = _period;
    try {
      final lessons = await repo.listAll('lessons',
          where: And([
            const Eq('deleted', false),
            Gte('starts_at', toPbDateTime(from)),
            Lte('starts_at', toPbDateTime(to)),
          ]),
          sort: 'starts_at',
          expand: 'cadet,instructor,car');
      final rows = <List<String>>[
        [
          'Дата',
          'Начало',
          'Окончание',
          'Минут',
          'Курсант',
          'Инструктор',
          'Автомобиль',
          'Тип',
          'Статус'
        ],
        for (final l in lessons)
          if (l.dateTime('starts_at') != null)
            [
              fmtDate(l.dateTime('starts_at')!),
              fmtTime(l.dateTime('starts_at')!),
              l.dateTime('ends_at') == null
                  ? ''
                  : fmtTime(l.dateTime('ends_at')!),
              '${lessonMinutes(l)}',
              l.one('cadet')?.str('full_name') ?? '',
              l.one('instructor')?.str('full_name') ?? '',
              l.one('car')?.str('plate') ?? '',
              lessonKinds[l.str('kind')] ?? '',
              lessonStatuses[l.str('status')] ?? '',
            ],
      ];
      final name = 'zanyatiya_${fmtDateIso(from)}_${fmtDateIso(to)}.csv';
      final ok = downloadTextFile(name, buildCsv(rows));
      messenger.showSnackBar(SnackBar(
          content: Text(ok
              ? 'Файл $name сохранён: ${rows.length - 1} занятий'
              : 'Скачивание доступно только в браузере')));
    } catch (e) {
      messenger
          .showSnackBar(SnackBar(content: Text('Не удалось выгрузить: $e')));
    }
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
          child: Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            alignment: WrapAlignment.spaceBetween,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.insights, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Отчёт', style: theme.textTheme.headlineSmall),
                ],
              ),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SegmentedButton<int>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(value: 30, label: Text('30 дней')),
                      ButtonSegment(value: 90, label: Text('90 дней')),
                      ButtonSegment(value: 365, label: Text('Год')),
                    ],
                    selected: {_days},
                    onSelectionChanged: (s) => _setPeriod(s.first),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _export,
                    icon: const Icon(Icons.download),
                    label: const Text('Занятия в CSV'),
                  ),
                ],
              ),
            ],
          ),
        ),
        Expanded(
          child: ChangeNotifierProvider.value(
            value: _notifier,
            child: Consumer<DetailsNotifier<ReportData>>(
              builder: (context, n, _) => DetailsStateView(
                status: n.status,
                error: n.error,
                notFound: n.notFound,
                hasData: n.data != null,
                notFoundMessage: 'Нет данных',
                onRetry: n.load,
                builder: () => _ReportView(data: n.data!),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

String fmtDateIso(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

class _ReportView extends StatelessWidget {
  const _ReportView({required this.data});

  final ReportData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final d = data;
    final studying = d.cadetsByStatus['studying'] ?? 0;
    final total = d.cadetsByStatus.values.fold(0, (a, b) => a + b);
    final hours = d.drivingMinutes / 60;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Период: ${fmtDate(d.from)} — ${fmtDate(d.to)}',
              style: theme.textTheme.bodyMedium),
          const SizedBox(height: 12),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              _Kpi(Icons.school_outlined, 'Курсантов обучается', '$studying',
                  'всего в базе: $total'),
              _Kpi(
                  Icons.event_available,
                  'Проведено занятий',
                  '${d.lessonsByStatus['done'] ?? 0}',
                  '${hours.toStringAsFixed(1)} ч вождения'),
              _Kpi(Icons.payments_outlined, 'Выручка', fmtMoney(d.revenueTotal),
                  'за период'),
              _Kpi(
                  Icons.fact_check_outlined,
                  'Сдаваемость экзаменов',
                  d.examsTotal == 0 ? '—' : '${(d.passRate * 100).round()} %',
                  'сдано ${d.examsPassed} из ${d.examsTotal}'),
            ],
          ),
          const SizedBox(height: 20),
          _ChartCard(
            title: 'Выручка по месяцам',
            child: d.revenueByMonth.isEmpty
                ? const Text('Платежей за период нет')
                : SizedBox(
                    height: 220,
                    child: _BarChart(
                      labels: [
                        for (final k in d.revenueByMonth.keys) monthLabel(k)
                      ],
                      values: [
                        for (final v in d.revenueByMonth.values) v.toDouble()
                      ],
                      format: (v) => '${(v / 1000).round()} тыс.',
                      color: theme.colorScheme.primary,
                      labelColor: theme.colorScheme.onSurface,
                    ),
                  ),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: 'Занятия по статусам',
            child: _StatusBar(counts: d.lessonsByStatus),
          ),
          const SizedBox(height: 16),
          _ChartCard(
            title: 'Часы вождения по инструкторам',
            child: d.hoursByInstructor.isEmpty
                ? const Text('Проведённых занятий за период нет')
                : Column(
                    children: [
                      for (final e
                          in (d.hoursByInstructor.entries.toList()
                            ..sort((a, b) => b.value.compareTo(a.value))))
                        _HoursRow(
                          name: e.key,
                          minutes: e.value,
                          max: d.hoursByInstructor.values
                              .reduce((a, b) => a > b ? a : b),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Kpi extends StatelessWidget {
  const _Kpi(this.icon, this.title, this.value, this.note);

  final IconData icon;
  final String title;
  final String value;
  final String note;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return SizedBox(
      width: 250,
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(icon, size: 20, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(title, style: theme.textTheme.titleSmall)),
              ]),
              const SizedBox(height: 8),
              Text(value, style: theme.textTheme.headlineMedium),
              Text(note, style: theme.textTheme.bodySmall),
            ],
          ),
        ),
      ),
    );
  }
}

class _ChartCard extends StatelessWidget {
  const _ChartCard({required this.title, required this.child});

  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) => Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 12),
              child,
            ],
          ),
        ),
      );
}

class _HoursRow extends StatelessWidget {
  const _HoursRow(
      {required this.name, required this.minutes, required this.max});

  final String name;
  final int minutes;
  final int max;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          SizedBox(
            width: 150,
            child: Text(name, overflow: TextOverflow.ellipsis),
          ),
          Expanded(
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: max == 0 ? 0 : minutes / max,
                minHeight: 14,
                color: theme.colorScheme.secondary,
              ),
            ),
          ),
          SizedBox(
            width: 70,
            child: Text('${(minutes / 60).toStringAsFixed(1)} ч',
                textAlign: TextAlign.right),
          ),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar({required this.counts});

  final Map<String, int> counts;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = {
      'done': scheme.tertiary,
      'planned': scheme.primary,
      'cancelled': scheme.outline,
      'no_show': scheme.error,
    };
    final total = counts.values.fold(0, (a, b) => a + b);
    if (total == 0) return const Text('Занятий за период нет');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: SizedBox(
            height: 24,
            child: Row(
              children: [
                for (final key in colors.keys)
                  if ((counts[key] ?? 0) > 0)
                    Expanded(
                      flex: counts[key]!,
                      child: Tooltip(
                        message: '${lessonStatuses[key]}: ${counts[key]}',
                        child: Container(color: colors[key]),
                      ),
                    ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 16,
          runSpacing: 4,
          children: [
            for (final key in colors.keys)
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(width: 12, height: 12, color: colors[key]),
                  const SizedBox(width: 6),
                  Text('${lessonStatuses[key]}: ${counts[key] ?? 0}'),
                ],
              ),
          ],
        ),
      ],
    );
  }
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.labels,
    required this.values,
    required this.format,
    required this.color,
    required this.labelColor,
  });

  final List<String> labels;
  final List<double> values;
  final String Function(double value) format;
  final Color color;
  final Color labelColor;

  @override
  Widget build(BuildContext context) => Semantics(
        label: 'Столбчатая диаграмма: '
            '${[
          for (var i = 0; i < labels.length; i++)
            '${labels[i]} — ${format(values[i])}'
        ].join(', ')}',
        child: CustomPaint(
          size: Size.infinite,
          painter: _BarPainter(labels, values, format, color, labelColor),
        ),
      );
}

class _BarPainter extends CustomPainter {
  _BarPainter(
      this.labels, this.values, this.format, this.color, this.labelColor);

  final List<String> labels;
  final List<double> values;
  final String Function(double value) format;
  final Color color;
  final Color labelColor;

  void _text(Canvas canvas, String text, Offset center, double width) {
    final tp = TextPainter(
      text: TextSpan(
          text: text, style: TextStyle(color: labelColor, fontSize: 12)),
      textDirection: TextDirection.ltr,
      maxLines: 1,
      ellipsis: '…',
    )..layout(maxWidth: width);
    tp.paint(canvas, Offset(center.dx - tp.width / 2, center.dy));
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (values.isEmpty) return;
    const top = 20.0, bottom = 24.0;
    final maxValue = values.reduce((a, b) => a > b ? a : b);
    final chartHeight = size.height - top - bottom;
    final slot = size.width / values.length;
    final barWidth = (slot * 0.6).clamp(8.0, 64.0);
    final axis = Paint()
      ..color = labelColor.withValues(alpha: 0.4)
      ..strokeWidth = 1;
    canvas.drawLine(Offset(0, top + chartHeight),
        Offset(size.width, top + chartHeight), axis);
    final paint = Paint()..color = color;
    for (var i = 0; i < values.length; i++) {
      final h = maxValue == 0 ? 0.0 : values[i] / maxValue * chartHeight;
      final cx = slot * i + slot / 2;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(cx - barWidth / 2, top + chartHeight - h, barWidth, h),
          topLeft: const Radius.circular(4),
          topRight: const Radius.circular(4),
        ),
        paint,
      );
      _text(canvas, format(values[i]), Offset(cx, top + chartHeight - h - 16),
          slot);
      _text(canvas, labels[i], Offset(cx, top + chartHeight + 6), slot);
    }
  }

  @override
  bool shouldRepaint(_BarPainter old) =>
      old.values != values || old.labels != labels || old.color != color;
}
