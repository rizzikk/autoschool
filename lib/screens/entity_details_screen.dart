import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../domain/entities.dart';
import '../domain/entity_def.dart';
import '../domain/field_codec.dart';
import '../models/pb_record.dart';
import '../repositories/conditions.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../state/details_notifier.dart';
import '../widgets/deleted_badge.dart';
import '../widgets/dialogs.dart';
import '../widgets/state_views.dart';

class EntityDetailsScreen extends StatelessWidget {
  const EntityDetailsScreen({super.key, required this.def, required this.id});

  final EntityDef def;
  final String id;

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      key: ValueKey('${def.collection}/$id'),
      create: (context) {
        final repo = context.read<RecordRepository>();
        return DetailsNotifier<PbRecord>(
            () => repo.find(def.collection, id, expand: def.expand))
          ..load();
      },
      child: Consumer<DetailsNotifier<PbRecord>>(
        builder: (context, n, _) => Scaffold(
          appBar: AppBar(
            leading: BackButton(onPressed: () => context.go(def.path)),
            title: n.data == null
                ? Text(def.singular)
                : TitleWithBadge(
                    text: def.titleOf(n.data!), deleted: n.data!.deleted),
          ),
          body: DetailsStateView(
            status: n.status,
            error: n.error,
            notFound: n.notFound,
            hasData: n.data != null,
            notFoundMessage:
                'Такой записи нет, она в корзине или у вас нет к ней доступа.',
            onRetry: n.load,
            builder: () => _Body(def: def, record: n.data!, reload: n.load),
          ),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  const _Body({required this.def, required this.record, required this.reload});

  final EntityDef def;
  final PbRecord record;
  final Future<void> Function() reload;

  Future<void> _softDelete(BuildContext context) async {
    final repo = context.read<RecordRepository>();
    final ok = await confirmAction(context,
        title: 'Удалить в корзину?',
        message: 'Запись будет скрыта из списков, её можно восстановить.',
        confirmLabel: 'В корзину');
    if (!ok || !context.mounted) return;
    final done = await runWithFeedback(context,
        () => repo.update(def.collection, record.id, {'deleted': true}),
        success: 'Помещено в корзину');
    if (done && context.mounted) context.go(def.path);
  }

  Future<void> _hardDelete(BuildContext context) async {
    final repo = context.read<RecordRepository>();
    final ok = await confirmAction(context,
        title: 'Удалить навсегда?',
        message: 'Запись будет удалена без возможности восстановления.',
        confirmLabel: 'Удалить навсегда');
    if (!ok || !context.mounted) return;
    final done = await runWithFeedback(
        context, () => repo.delete(def.collection, record.id),
        success: 'Удалено навсегда');
    if (done && context.mounted) context.go(def.path);
  }

  Future<void> _restore(BuildContext context) async {
    final repo = context.read<RecordRepository>();
    final done = await runWithFeedback(context,
        () => repo.update(def.collection, record.id, {'deleted': false}),
        success: 'Запись восстановлена');
    if (done) await reload();
  }

  Future<void> _action(BuildContext context, RowAction a) async {
    final repo = context.read<RecordRepository>();
    if (a.confirm != null) {
      final ok = await confirmAction(context,
          title: a.label,
          message: a.confirm!,
          confirmLabel: 'Да',
          destructive: false);
      if (!ok || !context.mounted) return;
    }
    final done = await runWithFeedback(context, () => a.run(repo, record),
        success: a.success);
    if (done) await reload();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    final role = auth.role;
    final c = def.collection;
    final theme = Theme.of(context);
    final shown = [
      for (final f in def.fields)
        if (!f.createOnly) f
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Align(
        alignment: Alignment.topLeft,
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 820),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  if (!record.deleted && auth.canOn(c, EntityOp.edit))
                    FilledButton.icon(
                      onPressed: () =>
                          context.go(editLocation(def.path, record.id)),
                      icon: const Icon(Icons.edit),
                      label: const Text('Изменить'),
                    ),
                  if (c == 'cadets' && auth.has(Permission.viewProgress))
                    OutlinedButton.icon(
                      onPressed: () => context.go(progressLocation(record.id)),
                      icon: const Icon(Icons.trending_up),
                      label: const Text('Прогресс и допуск'),
                    ),
                  if (role != null)
                    for (final a in def.actions)
                      if (a.visible(role, record))
                        OutlinedButton.icon(
                          onPressed: () => _action(context, a),
                          icon: Icon(a.icon),
                          label: Text(a.label),
                        ),
                  if (!record.deleted &&
                      def.softDelete &&
                      auth.canOn(c, EntityOp.softDelete))
                    OutlinedButton.icon(
                      onPressed: () => _softDelete(context),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('В корзину'),
                    ),
                  if (record.deleted && auth.canOn(c, EntityOp.restore))
                    FilledButton.tonalIcon(
                      onPressed: () => _restore(context),
                      icon: const Icon(Icons.restore_from_trash),
                      label: const Text('Восстановить'),
                    ),
                  if ((record.deleted || !def.softDelete) &&
                      auth.canOn(c, EntityOp.hardDelete))
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                          foregroundColor: theme.colorScheme.error),
                      onPressed: () => _hardDelete(context),
                      icon: const Icon(Icons.delete_forever_outlined),
                      label: const Text('Удалить навсегда'),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              Card(
                margin: EdgeInsets.zero,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    children: [
                      for (final f in shown)
                        _FieldRow(
                            label: f.label, value: displayField(f, record)),
                    ],
                  ),
                ),
              ),
              for (final rel in def.related)
                if (auth.canOn(rel.collection, EntityOp.view))
                  _RelatedSection(def: rel, ownerId: record.id),
            ],
          ),
        ),
      ),
    );
  }
}

class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: LayoutBuilder(
        builder: (context, c) {
          final narrow = c.maxWidth < 420;
          final labelText = Text(label,
              style: theme.textTheme.bodySmall
                  ?.copyWith(color: theme.colorScheme.onSurfaceVariant));
          final valueText =
              SelectableText(value, style: theme.textTheme.bodyLarge);
          if (narrow) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [labelText, valueText],
            );
          }
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 230, child: labelText),
              Expanded(child: valueText),
            ],
          );
        },
      ),
    );
  }
}

class _RelatedSection extends StatefulWidget {
  const _RelatedSection({required this.def, required this.ownerId});

  final RelatedDef def;
  final String ownerId;

  @override
  State<_RelatedSection> createState() => _RelatedSectionState();
}

class _RelatedSectionState extends State<_RelatedSection> {
  late Future<List<PbRecord>> _future = _load();

  Future<List<PbRecord>> _load() async {
    final target = entityDefs[widget.def.collection]!;
    final page = await context.read<RecordRepository>().list(
          target.collection,
          perPage: 8,
          where: allOf([
            Eq(widget.def.field, widget.ownerId),
            if (target.softDelete) const Eq('deleted', false),
          ]),
          sort: widget.def.sort,
          expand: target.expand,
        );
    return page.items;
  }

  @override
  Widget build(BuildContext context) {
    final target = entityDefs[widget.def.collection]!;
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(top: 16),
      child: Card(
        margin: EdgeInsets.zero,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(widget.def.title, style: theme.textTheme.titleMedium),
              const SizedBox(height: 8),
              FutureBuilder<List<PbRecord>>(
                future: _future,
                builder: (context, snap) {
                  if (snap.hasError) {
                    return Row(
                      children: [
                        Expanded(
                            child: Text('Не удалось загрузить: ${snap.error}')),
                        TextButton(
                          onPressed: () => setState(() => _future = _load()),
                          child: const Text('Повторить'),
                        ),
                      ],
                    );
                  }
                  if (!snap.hasData) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 8),
                      child: LinearProgressIndicator(),
                    );
                  }
                  final items = snap.data!;
                  if (items.isEmpty) return const Text('Нет записей');
                  return Column(
                    children: [
                      for (final r in items)
                        ListTile(
                          dense: true,
                          contentPadding: EdgeInsets.zero,
                          title: Text(target.titleOf(r)),
                          subtitle: target.subtitleOf == null
                              ? null
                              : Text(target.subtitleOf!(r)),
                          trailing: const Icon(Icons.chevron_right),
                          onTap: () =>
                              context.go(detailsLocation(target.path, r.id)),
                        ),
                    ],
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
