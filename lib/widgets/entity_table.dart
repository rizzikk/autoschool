import 'package:flutter/material.dart';

import '../core/breakpoints.dart';

class TableColumnSpec<T> {
  final String label;

  final String? sortField;
  final bool numeric;
  final Widget Function(T item) build;

  const TableColumnSpec({
    required this.label,
    required this.build,
    this.sortField,
    this.numeric = false,
  });
}

class EntityTable<T> extends StatelessWidget {
  static const double cardBreakpoint = mediumBreakpoint;

  final List<TableColumnSpec<T>> columns;
  final List<T> items;
  final String Function(T item) idOf;
  final Set<String> selected;
  final ValueChanged<String>? onToggleSelect;
  final ValueChanged<bool>? onSelectAll;
  final String? sortField;
  final bool sortAscending;
  final void Function(String field)? onSort;
  final List<Widget> Function(T item)? actions;
  final ValueChanged<T>? onOpen;

  final bool Function(T item)? isInactive;

  final Widget? cardsHeader;
  final Widget? cardsFooter;

  const EntityTable({
    super.key,
    required this.columns,
    required this.items,
    required this.idOf,
    this.selected = const {},
    this.onToggleSelect,
    this.onSelectAll,
    this.sortField,
    this.sortAscending = true,
    this.onSort,
    this.actions,
    this.onOpen,
    this.isInactive,
    this.cardsHeader,
    this.cardsFooter,
  });

  bool get _selectable => onToggleSelect != null;

  bool get _hasActions =>
      actions != null && items.any((item) => actions!(item).isNotEmpty);

  @override
  Widget build(BuildContext context) {
    final narrow = MediaQuery.sizeOf(context).width < cardBreakpoint;
    return narrow ? _buildCards(context) : _buildTable(context);
  }

  int? get _sortColumnIndex {
    if (sortField == null) return null;
    final i = columns.indexWhere((c) => c.sortField == sortField);
    return i == -1 ? null : i;
  }

  static const double _headHeight = 56;
  static const double _rowHeight = 52;

  Widget _buildTable(BuildContext context) {
    final theme = Theme.of(context);
    final table = DataTable(
      showCheckboxColumn: _selectable,
      sortColumnIndex: _sortColumnIndex,
      sortAscending: sortAscending,
      onSelectAll: _selectable && onSelectAll != null
          ? (value) => onSelectAll!(value ?? false)
          : null,
      headingTextStyle: theme.textTheme.titleSmall,
      headingRowHeight: _headHeight,
      dataRowMinHeight: _rowHeight,
      dataRowMaxHeight: _rowHeight,
      columnSpacing: 20,
      horizontalMargin: 12,
      columns: [
        for (final c in columns)
          DataColumn(
            label: Text(c.label),
            numeric: c.numeric,
            onSort: c.sortField == null || onSort == null
                ? null
                : (columnIndex, ascending) => onSort!(c.sortField!),
          ),
      ],
      rows: [for (final item in items) _buildRow(item, theme)],
    );

    return SingleChildScrollView(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: LayoutBuilder(
              builder: (context, constraints) => _HorizontalScroll(
                child: ConstrainedBox(
                  constraints: BoxConstraints(minWidth: constraints.maxWidth),
                  child: table,
                ),
              ),
            ),
          ),
          if (_hasActions) _buildActionsPane(context, theme),
        ],
      ),
    );
  }

  Widget _buildActionsPane(BuildContext context, ThemeData theme) {
    final line = Divider.createBorderSide(context);
    return Theme(
      data: theme.copyWith(visualDensity: VisualDensity.compact),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Container(
              height: _headHeight,
              alignment: Alignment.centerLeft,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              decoration:
                  BoxDecoration(border: Border(left: line, bottom: line)),
              child: Text('Действия', style: theme.textTheme.titleSmall),
            ),
            for (var i = 0; i < items.length; i++)
              Container(
                height: _rowHeight,
                alignment: Alignment.centerLeft,
                padding: const EdgeInsets.symmetric(horizontal: 4),
                decoration: BoxDecoration(
                  color: _paneColor(theme, items[i]),
                  border: Border(
                    left: line,
                    bottom: i == items.length - 1 ? BorderSide.none : line,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: actions!(items[i]),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Color? _paneColor(ThemeData theme, T item) {
    if (selected.contains(idOf(item))) {
      return theme.colorScheme.primary.withValues(alpha: 0.08);
    }
    if (isInactive?.call(item) ?? false) {
      return theme.colorScheme.surfaceContainerHighest;
    }
    return null;
  }

  DataRow _buildRow(T item, ThemeData theme) {
    final id = idOf(item);
    final inactive = isInactive?.call(item) ?? false;
    final isSelected = selected.contains(id);
    return DataRow(
      key: ValueKey(id),
      selected: isSelected,
      onSelectChanged: _selectable
          ? (value) {
              if ((value ?? false) != isSelected) onToggleSelect!(id);
            }
          : null,
      color: inactive
          ? WidgetStatePropertyAll(theme.colorScheme.surfaceContainerHighest)
          : null,
      cells: [
        for (final c in columns)
          DataCell(
            _dim(c.build(item), inactive),
            onTap: onOpen == null ? null : () => onOpen!(item),
          ),
      ],
    );
  }

  Widget _buildCards(BuildContext context) {
    final header = cardsHeader;
    final footer = cardsFooter;
    final sortBar = _buildSortBar(context);
    final before = [
      if (header != null) header,
      if (sortBar != null)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: sortBar,
        ),
    ];
    final count = before.length + items.length + (footer == null ? 0 : 1);
    return ListView.separated(
      padding: const EdgeInsets.only(bottom: 8),
      itemCount: count,
      separatorBuilder: (context, index) =>
          SizedBox(height: header != null && index == 0 ? 0 : 8),
      itemBuilder: (context, index) {
        if (index < before.length) return before[index];
        final i = index - before.length;
        if (i < items.length) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: _buildCard(context, items[i]),
          );
        }
        return footer!;
      },
    );
  }

  Widget _buildCard(BuildContext context, T item) {
    final theme = Theme.of(context);
    final id = idOf(item);
    final inactive = isInactive?.call(item) ?? false;
    final isSelected = selected.contains(id);
    return Card(
      key: ValueKey(id),
      margin: EdgeInsets.zero,
      color: isSelected
          ? theme.colorScheme.secondaryContainer
          : inactive
              ? theme.colorScheme.surfaceContainerHighest
              : null,
      child: InkWell(
        onTap: onOpen == null ? null : () => onOpen!(item),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_selectable)
                Checkbox(
                  value: isSelected,
                  onChanged: (_) => onToggleSelect!(id),
                )
              else
                const SizedBox(width: 12),
              Expanded(
                child: _dim(
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 10),
                      DefaultTextStyle.merge(
                        style: theme.textTheme.titleMedium,
                        child: columns.first.build(item),
                      ),
                      const SizedBox(height: 6),
                      for (final c in columns.skip(1))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              SizedBox(
                                width: 110,
                                child: Text(
                                  c.label,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: theme.colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ),
                              Expanded(child: c.build(item)),
                            ],
                          ),
                        ),
                    ],
                  ),
                  inactive,
                ),
              ),
              if (actions != null)
                Column(
                    mainAxisSize: MainAxisSize.min, children: actions!(item)),
            ],
          ),
        ),
      ),
    );
  }

  Widget? _buildSortBar(BuildContext context) {
    final sortable = columns.where((c) => c.sortField != null).toList();
    if (sortable.isEmpty || onSort == null) return null;
    final current =
        sortable.any((c) => c.sortField == sortField) ? sortField : null;
    return Row(
      children: [
        const Text('Сортировка:'),
        const SizedBox(width: 8),
        DropdownButton<String>(
          value: current,
          hint: const Text('—'),
          items: [
            for (final c in sortable)
              DropdownMenuItem(value: c.sortField, child: Text(c.label)),
          ],
          onChanged: (field) {
            if (field != null && field != sortField) onSort!(field);
          },
        ),
        IconButton(
          tooltip: sortAscending ? 'По возрастанию' : 'По убыванию',
          icon: Icon(sortAscending ? Icons.arrow_upward : Icons.arrow_downward),
          onPressed: current == null ? null : () => onSort!(sortField!),
        ),
      ],
    );
  }

  static Widget _dim(Widget child, bool inactive) =>
      inactive ? Opacity(opacity: 0.6, child: child) : child;
}

class _HorizontalScroll extends StatefulWidget {
  const _HorizontalScroll({required this.child});

  final Widget child;

  @override
  State<_HorizontalScroll> createState() => _HorizontalScrollState();
}

class _HorizontalScrollState extends State<_HorizontalScroll> {
  final _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scrollbar(
        controller: _controller,
        thumbVisibility: true,
        child: SingleChildScrollView(
          controller: _controller,
          scrollDirection: Axis.horizontal,
          child: widget.child,
        ),
      );
}
