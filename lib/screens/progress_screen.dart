import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../domain/entities.dart';
import '../domain/progress.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../state/details_notifier.dart';
import '../widgets/state_views.dart';

class ProgressScreen extends StatelessWidget {
  const ProgressScreen({super.key, this.cadetId});

  final String? cadetId;

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final id = auth.role == Role.cadet ? auth.user?.profileId : cadetId;
    if (id == null) {
      if (auth.role == Role.cadet) {
        return const MessageView(
          icon: Icons.person_search,
          title: 'Анкета не заполнена',
          message: 'Прогресс появится после заполнения анкеты курсанта.',
        );
      }
      return const _CadetPicker();
    }
    return _ProgressBody(key: ValueKey(id), cadetId: id);
  }
}

class _CadetPicker extends StatefulWidget {
  const _CadetPicker();

  @override
  State<_CadetPicker> createState() => _CadetPickerState();
}

class _CadetPickerState extends State<_CadetPicker> {
  late Future<List<PbRecord>> _future = _load();

  Future<List<PbRecord>> _load() => context.read<RecordRepository>().listAll(
        'cadets',
        where: const Eq('deleted', false),
        sort: 'full_name',
        expand: 'category',
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return FutureBuilder<List<PbRecord>>(
      future: _future,
      builder: (context, snap) {
        if (snap.hasError) {
          return ErrorView(
              message: 'Не удалось загрузить курсантов: ${snap.error}',
              onRetry: () => setState(() => _future = _load()));
        }
        if (!snap.hasData) return const LoadingView();
        final cadets = snap.data!;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
              child: Row(
                children: [
                  Icon(Icons.trending_up, color: theme.colorScheme.primary),
                  const SizedBox(width: 10),
                  Text('Прогресс курсантов',
                      style: theme.textTheme.headlineSmall),
                ],
              ),
            ),
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16),
              child: Text('Выберите курсанта, чтобы увидеть пройденные часы '
                  'вождения, результаты экзаменов и допуск к итоговому экзамену.'),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: cadets.length,
                itemBuilder: (context, i) {
                  final c = cadets[i];
                  return ListTile(
                    leading: const Icon(Icons.school_outlined),
                    title: Text(c.str('full_name')),
                    subtitle: Text(
                        '${c.one('category')?.str('code') ?? ''} · ${cadetStatuses[c.str('status')] ?? ''}'),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => context.go(progressLocation(c.id)),
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }
}

typedef _ProgressData = ({PbRecord cadet, CadetProgress progress});

class _ProgressBody extends StatelessWidget {
  const _ProgressBody({super.key, required this.cadetId});

  final String cadetId;

  Future<_ProgressData?> _load(BuildContext context) async {
    final repo = context.read<RecordRepository>();
    final auth = context.read<AuthNotifier>();
    final cadet = await repo.find('cadets', cadetId, expand: 'category');
    if (cadet == null) return null;
    final category = cadet.one('category');
    if (category == null) return null;
    final byCadet = And([Eq('cadet', cadetId), const Eq('deleted', false)]);
    final canSeePayments = auth.canOn('payments', EntityOp.view);
    final results = await Future.wait([
      repo.listAll('lessons', where: byCadet),
      repo.listAll('exams', where: byCadet),
      repo.listAll('medical_certificates', where: byCadet),
      if (canSeePayments) repo.listAll('payments', where: byCadet),
    ]);
    return (
      cadet: cadet,
      progress: computeProgress(
        category: category,
        lessons: results[0],
        exams: results[1],
        certificates: results[2],
        payments: canSeePayments ? results[3] : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return ChangeNotifierProvider(
      create: (context) =>
          DetailsNotifier<_ProgressData>(() => _load(context))..load(),
      child: Consumer<DetailsNotifier<_ProgressData>>(
        builder: (context, n, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (auth.role != Role.cadet)
              Align(
                alignment: Alignment.centerLeft,
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(8, 8, 8, 0),
                  child: TextButton.icon(
                    onPressed: () => context.go(progressPath),
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Все курсанты'),
                  ),
                ),
              ),
            Expanded(
              child: DetailsStateView(
                status: n.status,
                error: n.error,
                notFound: n.notFound,
                hasData: n.data != null,
                notFoundMessage: 'Курсант не найден или у вас нет доступа.',
                onRetry: n.load,
                builder: () => _ProgressView(data: n.data!),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressView extends StatelessWidget {
  const _ProgressView({required this.data});

  final _ProgressData data;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final p = data.progress;
    final cadet = data.cadet;
    final admitted = p.admitted;
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 760),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(cadet.str('full_name'),
                  style: theme.textTheme.headlineSmall),
              Text(
                'Категория ${cadet.one('category')?.str('code') ?? ''} · '
                '${cadetStatuses[cadet.str('status')] ?? ''}',
                style: theme.textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              Card(
                color:
                    admitted ? scheme.tertiaryContainer : scheme.errorContainer,
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Icon(
                        admitted ? Icons.verified_outlined : Icons.block,
                        size: 36,
                        color: admitted
                            ? scheme.onTertiaryContainer
                            : scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Text(
                          admitted
                              ? (p.hasUnknown
                                  ? 'Допущен к итоговому экзамену по проверенным условиям'
                                  : 'Допущен к итоговому экзамену')
                              : 'Не допущен к итоговому экзамену: не выполнено '
                                  'условий — ${p.failedCount}',
                          style: theme.textTheme.titleMedium?.copyWith(
                            color: admitted
                                ? scheme.onTertiaryContainer
                                : scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              Text('Вождение', style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: LinearProgressIndicator(
                  value: p.practiceFraction,
                  minHeight: 12,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                  '${p.practiceMinutes ~/ 60} из ${p.practiceRequiredMinutes ~/ 60} ч '
                  '(${(p.practiceFraction * 100).round()} %)'),
              const SizedBox(height: 16),
              Text('Условия допуска', style: theme.textTheme.titleMedium),
              const SizedBox(height: 4),
              for (final c in p.conditions)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    switch (c.ok) {
                      true => Icons.check_circle,
                      false => Icons.cancel,
                      null => Icons.help_outline,
                    },
                    color: switch (c.ok) {
                      true => Colors.green.shade600,
                      false => scheme.error,
                      null => scheme.outline,
                    },
                  ),
                  title: Text(c.title),
                  subtitle: Text(c.detail),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
