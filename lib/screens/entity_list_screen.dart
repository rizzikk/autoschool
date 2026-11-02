import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../auth/auth_notifier.dart';
import '../auth/permissions.dart';
import '../core/api_exceptions.dart';
import '../core/breakpoints.dart';
import '../domain/entity_def.dart';
import '../models/list_query.dart';
import '../models/pb_record.dart';
import '../repositories/record_repository.dart';
import '../router/locations.dart';
import '../state/entity_list_notifier.dart';
import '../state/load_status.dart';
import '../state/relation_options.dart';
import '../util/format.dart';
import '../widgets/cell_text.dart';
import '../widgets/debounced_text_field.dart';
import '../widgets/deleted_badge.dart';
import '../widgets/dialogs.dart';
import '../widgets/entity_table.dart';
import '../widgets/labeled_dropdown.dart';
import '../widgets/pagination_bar.dart';
import '../widgets/selection_bar.dart';
import '../widgets/state_views.dart';

class EntityListScreen extends StatefulWidget {
  const EntityListScreen({super.key, required this.def, required this.params});

  final EntityDef def;
  final Map<String, String> params;

  @override
  State<EntityListScreen> createState() => _EntityListScreenState();
}

class _EntityListScreenState extends State<EntityListScreen> {
  late final EntityListNotifier _notifier;
  late final RelationOptions _lookup;
  final Map<String, List<PbRecord>> _filterOptions = {};
  bool _filtersOpen = false;

  final _topKey = GlobalKey();

  EntityDef get def => widget.def;

  @override
  void initState() {
    super.initState();
    final auth = context.read<AuthNotifier>();
    _lookup = context.read<RelationOptions>();
    _notifier = EntityListNotifier(
      def,
      context.read<RecordRepository>(),
      query: def.queryFromParams(widget.params),
      canSeeDeleted: auth.canOn(def.collection, EntityOp.viewDeleted),
      onChanged: _lookup.invalidate,
    )..load();
    _filtersOpen = _notifier.query.activeFilterCount > 0;
    _loadFilterOptions();
  }

  Future<void> _loadFilterOptions() async {
    for (final f in def.filters.where((f) => f.kind == FilterKind.relation)) {
      try {
        final items = await _lookup.load(f.relation!);
        if (!mounted) return;
        setState(() => _filterOptions[f.key] = items);
      } on ApiException {
        continue;
      }
    }
  }

  @override
  void didUpdateWidget(EntityListScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!mapEquals(oldWidget.params, widget.params)) {
      _notifier.syncWithQuery(def.queryFromParams(widget.params));
    }
  }

  @override
  void dispose() {
    _notifier.dispose();
    super.dispose();
  }

  void _go(ListQuery q) => context.go(listLocation(def.path, q));

  Future<void> _softDelete(PbRecord r) async {
    final ok = await confirmAction(context,
        title: 'Удалить в корзину?',
        message: '«${def.titleOf(r)}» будет скрыта из списков. '
            'Запись можно восстановить.',
        confirmLabel: 'В корзину');
    if (ok && mounted) {
      await runWithFeedback(context, () => _notifier.softDelete(r.id),
          success: 'Помещено в корзину');
    }
  }

  Future<void> _hardDelete(PbRecord r) async {
    final ok = await confirmAction(context,
        title: 'Удалить навсегда?',
        message: '«${def.titleOf(r)}» будет удалена без возможности '
            'восстановления. Если на запись есть ссылки, сервер откажет.',
        confirmLabel: 'Удалить навсегда');
    if (ok && mounted) {
      await runWithFeedback(context, () => _notifier.hardDelete(r.id),
          success: 'Удалено навсегда');
    }
  }

  Future<void> _restore(PbRecord r) =>
      runWithFeedback(context, () => _notifier.restore(r.id),
          success: 'Запись восстановлена');

  Future<void> _runAction(RowAction a, PbRecord r) async {
    if (a.confirm != null) {
      final ok = await confirmAction(context,
          title: a.label,
          message: a.confirm!,
          confirmLabel: 'Да',
          destructive: false);
      if (!ok || !mounted) return;
    }
    await runWithFeedback(context, () => _notifier.runAction(a, r),
        success: a.success);
  }

  Future<void> _bulk(
    String title,
    String message,
    String confirmLabel,
    Future<BulkResult> Function() op,
    String doneText,
  ) async {
    final ok = await confirmAction(context,
        title: title, message: message, confirmLabel: confirmLabel);
    if (!ok || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final r = await op();
    final failed = r.hasErrors
        ? '. Не удалось: ${r.failed.length} (${r.failed.first})'
        : '';
    messenger
        .showSnackBar(SnackBar(content: Text('$doneText: ${r.done}$failed')));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthNotifier>();
    return ListenableBuilder(
      listenable: _notifier,
      builder: (context, _) {
        final role = auth.role;
        final q = _notifier.query;
        final result = _notifier.result;
        final canCreate = auth.canOn(def.collection, EntityOp.create);
        final canSoft =
            def.softDelete && auth.canOn(def.collection, EntityOp.softDelete);
        final canRestore =
            def.softDelete && auth.canOn(def.collection, EntityOp.restore);
        final canHard = auth.canOn(def.collection, EntityOp.hardDelete);
        final canSeeDeleted =
            def.softDelete && auth.canOn(def.collection, EntityOp.viewDeleted);
        final inTrash = q.deleted == DeletedMode.only;
        final selectable = canSoft || canRestore || canHard;
        final title =
            role == Role.cadet ? (def.cadetLabel ?? def.plural) : def.plural;

        final selectionBar = !_notifier.hasSelection
            ? null
            : SelectionBar(
                count: _notifier.selected.length,
                onClear: _notifier.clearSelection,
                actions: [
                  if (canSoft && !inTrash)
                    FilledButton.icon(
                      style: _dangerStyle(context),
                      onPressed: () => _bulk(
                          'Удалить выбранные в корзину?',
                          'Выбрано записей: ${_notifier.selected.length}. '
                              'Их можно будет восстановить.',
                          'В корзину',
                          _notifier.softDeleteSelected,
                          'Помещено в корзину'),
                      icon: const Icon(Icons.delete_outline),
                      label: const Text('В корзину'),
                    ),
                  if (canRestore && inTrash)
                    FilledButton.icon(
                      onPressed: () async {
                        final r = await _notifier.restoreSelected();
                        if (!context.mounted) return;
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text('Восстановлено: ${r.done}')));
                      },
                      icon: const Icon(Icons.restore_from_trash),
                      label: const Text('Восстановить'),
                    ),
                  if (canHard && (inTrash || !def.softDelete))
                    FilledButton.icon(
                      style: _dangerStyle(context),
                      onPressed: () => _bulk(
                          'Удалить выбранные навсегда?',
                          'Выбрано записей: ${_notifier.selected.length}. '
                              'Восстановить их будет нельзя.',
                          'Удалить навсегда',
                          _notifier.hardDeleteSelected,
                          'Удалено навсегда'),
                      icon: const Icon(Icons.delete_forever),
                      label: const Text('Удалить навсегда'),
                    ),
                ],
              );
        final scrollAll = screenSizeOf(context) == ScreenSize.compact &&
            result.items.isNotEmpty &&
            _notifier.status != LoadStatus.error;
        final top = KeyedSubtree(
          key: _topKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _header(context, title, canCreate),
              _toolbar(context, q, canSeeDeleted),
            ],
          ),
        );
        final pager = result.total > 0
            ? PaginationBar(
                result: result,
                size: q.size,
                onPage: (p) => _go(q.copyWith(page: p)),
                onSize: (s) => _go(q.copyWith(size: s)),
              )
            : null;
        final table = EntityTable<PbRecord>(
          columns: [
            for (var i = 0; i < def.columns.length; i++)
              TableColumnSpec<PbRecord>(
                label: def.columns[i].label,
                sortField: def.columns[i].sortField,
                numeric: def.columns[i].numeric,
                build: (r) => i == 0
                    ? TitleWithBadge(
                        text: def.columns[i].text(r), deleted: r.deleted)
                    : CellText(def.columns[i].text(r)),
              ),
          ],
          items: result.items,
          idOf: (r) => r.id,
          selected: _notifier.selected,
          onToggleSelect: selectable ? _notifier.toggleSelection : null,
          onSelectAll: selectable
              ? (v) => _notifier.setSelection(result.items.map((r) => r.id), v)
              : null,
          sortField: q.sortField,
          sortAscending: q.sortAscending,
          onSort: (field) => _go(q.copyWith(
            sortField: field,
            sortAscending: field == q.sortField ? !q.sortAscending : true,
          )),
          isInactive: (r) => r.deleted,
          onOpen: (r) => context.go(detailsLocation(def.path, r.id)),
          actions: (r) => _rowActions(context, auth, r),
          cardsHeader: scrollAll ? top : null,
          cardsFooter: scrollAll ? pager : null,
        );

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!scrollAll) top,
            if (selectionBar != null) selectionBar,
            Expanded(
              child: ListStateView(
                status: _notifier.status,
                error: _notifier.error,
                hasData: result.items.isNotEmpty,
                emptyTitle: 'Ничего не найдено',
                emptyMessage: q.hasFilters
                    ? 'По заданным условиям записей нет. Измените поиск или фильтры.'
                    : 'Записей пока нет.',
                onRetry: _notifier.load,
                onResetFilters:
                    q.hasFilters ? () => _go(q.clearFilters()) : null,
                child: table,
              ),
            ),
            if (!scrollAll && pager != null) pager,
          ],
        );
      },
    );
  }

  ButtonStyle _dangerStyle(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return FilledButton.styleFrom(
        backgroundColor: scheme.error, foregroundColor: scheme.onError);
  }

  List<Widget> _rowActions(
      BuildContext context, AuthNotifier auth, PbRecord r) {
    final role = auth.role;
    final c = def.collection;
    return [
      if (!r.deleted && auth.canOn(c, EntityOp.edit))
        IconButton(
          tooltip: 'Изменить',
          icon: const Icon(Icons.edit_outlined),
          onPressed: () => context.go(editLocation(def.path, r.id)),
        ),
      if (role != null)
        for (final a in def.actions)
          if (a.visible(role, r))
            IconButton(
              tooltip: a.label,
              icon: Icon(a.icon),
              onPressed: () => _runAction(a, r),
            ),
      if (!r.deleted && def.softDelete && auth.canOn(c, EntityOp.softDelete))
        IconButton(
          tooltip: 'В корзину',
          icon: const Icon(Icons.delete_outline),
          onPressed: () => _softDelete(r),
        ),
      if (r.deleted && auth.canOn(c, EntityOp.restore))
        IconButton(
          tooltip: 'Восстановить',
          icon: const Icon(Icons.restore_from_trash),
          onPressed: () => _restore(r),
        ),
      if ((r.deleted || !def.softDelete) && auth.canOn(c, EntityOp.hardDelete))
        IconButton(
          tooltip: 'Удалить навсегда',
          icon: const Icon(Icons.delete_forever_outlined),
          onPressed: () => _hardDelete(r),
        ),
    ];
  }

  Widget _header(BuildContext context, String title, bool canCreate) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        alignment: WrapAlignment.spaceBetween,
        children: [
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(def.icon, color: theme.colorScheme.primary),
              const SizedBox(width: 10),
              Text(title, style: theme.textTheme.headlineSmall),
            ],
          ),
          if (canCreate)
            FilledButton.icon(
              onPressed: () => context.go(newLocation(def.path)),
              icon: const Icon(Icons.add),
              label: Text('Добавить ${def.accusative}'),
            ),
        ],
      ),
    );
  }

  Widget _toolbar(BuildContext context, ListQuery q, bool canSeeDeleted) {
    final compact = screenSizeOf(context) == ScreenSize.compact;
    final hasFilterControls = def.filters.isNotEmpty || canSeeDeleted;
    final showFilters = hasFilterControls && (!compact || _filtersOpen);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            spacing: 12,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              if (def.searchFields.isNotEmpty)
                DebouncedTextField(
                  value: q.search,
                  label: 'Поиск',
                  hint: 'Введите часть названия или имени',
                  icon: Icons.search,
                  width: compact ? double.infinity : 320,
                  onChanged: (v) => _go(q.copyWith(search: v)),
                ),
              if (compact && hasFilterControls)
                OutlinedButton.icon(
                  onPressed: () => setState(() => _filtersOpen = !_filtersOpen),
                  icon: const Icon(Icons.filter_alt_outlined),
                  label: Text(q.activeFilterCount == 0
                      ? 'Фильтры'
                      : 'Фильтры (${q.activeFilterCount})'),
                ),
              if (q.hasFilters)
                TextButton.icon(
                  onPressed: () => _go(q.clearFilters()),
                  icon: const Icon(Icons.filter_alt_off),
                  label: const Text('Сбросить'),
                ),
            ],
          ),
          if (showFilters) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 12,
              runSpacing: 10,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                for (final f in def.filters)
                  _filterControl(context, q, f, compact),
                if (canSeeDeleted)
                  SegmentedButton<DeletedMode>(
                    showSelectedIcon: false,
                    segments: const [
                      ButtonSegment(
                          value: DeletedMode.active,
                          label: Text('Действующие')),
                      ButtonSegment(
                          value: DeletedMode.only,
                          icon: Icon(Icons.delete_outline),
                          label: Text('Корзина')),
                      ButtonSegment(value: DeletedMode.all, label: Text('Все')),
                    ],
                    selected: {q.deleted},
                    onSelectionChanged: (s) =>
                        _go(q.copyWith(deleted: s.first)),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _filterControl(
      BuildContext context, ListQuery q, FilterDef f, bool compact) {
    final width = compact ? 160.0 : 190.0;
    switch (f.kind) {
      case FilterKind.select:
        return LabeledDropdown<String>(
          label: f.label,
          value: q.filters[f.key],
          options: f.options,
          width: width,
          onChanged: (v) => _go(q.withFilter(f.key, v)),
        );
      case FilterKind.relation:
        final items = _filterOptions[f.key] ?? const <PbRecord>[];
        return LabeledDropdown<String>(
          label: f.label,
          value: q.filters[f.key],
          options: {
            for (final r in items) r.id: _lookup.labelOf(f.relation!, r),
          },
          width: width + 20,
          onChanged: (v) => _go(q.withFilter(f.key, v)),
        );
      case FilterKind.dateFrom:
      case FilterKind.dateTo:
        return _DateFilter(
          label: f.label,
          value: DateTime.tryParse(q.filters[f.key] ?? ''),
          width: width,
          onChanged: (d) => _go(q.withFilter(
              f.key,
              d == null
                  ? null
                  : '${d.year.toString().padLeft(4, '0')}-${two(d.month)}-${two(d.day)}')),
        );
    }
  }
}

class _DateFilter extends StatelessWidget {
  const _DateFilter({
    required this.label,
    required this.value,
    required this.onChanged,
    required this.width,
  });

  final String label;
  final DateTime? value;
  final ValueChanged<DateTime?> onChanged;
  final double width;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      child: InkWell(
        borderRadius: BorderRadius.circular(4),
        onTap: () async {
          final now = DateTime.now();
          final picked = await showDatePicker(
            context: context,
            initialDate: value ?? now,
            firstDate: DateTime(2000),
            lastDate: DateTime(2100),
            helpText: label,
          );
          if (picked != null) onChanged(picked);
        },
        child: InputDecorator(
          decoration: InputDecoration(
            labelText: label,
            isDense: true,
            border: const OutlineInputBorder(),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            suffixIcon: value == null
                ? const Icon(Icons.calendar_today, size: 18)
                : IconButton(
                    tooltip: 'Снять фильтр',
                    iconSize: 18,
                    icon: const Icon(Icons.close),
                    onPressed: () => onChanged(null),
                  ),
          ),
          child: Text(value == null ? 'Любая' : fmtDate(value!)),
        ),
      ),
    );
  }
}
