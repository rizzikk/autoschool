import 'query_params.dart';

enum DeletedMode {
  active,

  only,

  all;

  static DeletedMode parse(String? value) => switch (value) {
        'only' => DeletedMode.only,
        'all' => DeletedMode.all,
        _ => DeletedMode.active,
      };
}

class ListQuery {
  const ListQuery({
    required this.defaultSort,
    this.defaultAscending = true,
    this.search = '',
    this.filters = const {},
    String? sortField,
    bool? ascending,
    this.page = 1,
    this.size = defaultPageSize,
    this.deleted = DeletedMode.active,
  })  : sortField = sortField ?? defaultSort,
        sortAscending = ascending ?? defaultAscending;

  static const reserved = {'q', 'sort', 'page', 'size', 'deleted'};

  final String defaultSort;
  final bool defaultAscending;
  final String search;

  final Map<String, String> filters;
  final String sortField;
  final bool sortAscending;
  final int page;
  final int size;
  final DeletedMode deleted;

  factory ListQuery.fromParams(
    Map<String, String> p, {
    required Set<String> sortFields,
    required Set<String> filterKeys,
    required String defaultSort,
    bool defaultAscending = true,
  }) {
    final sort = parseSort(p['sort'],
        allowed: sortFields,
        fallback: defaultSort,
        fallbackAscending: defaultAscending);
    return ListQuery(
      defaultSort: defaultSort,
      defaultAscending: defaultAscending,
      search: (p['q'] ?? '').trim(),
      filters: {
        for (final key in filterKeys)
          if ((p[key] ?? '').trim().isNotEmpty) key: p[key]!.trim(),
      },
      sortField: sort.field,
      ascending: sort.ascending,
      page: parsePage(p['page']),
      size: parseSize(p['size']),
      deleted: DeletedMode.parse(p['deleted']),
    );
  }

  Map<String, String> toParams() => {
        if (search.isNotEmpty) 'q': search,
        ...filters,
        if (sortField != defaultSort || sortAscending != defaultAscending)
          'sort': formatSort(sortField, sortAscending),
        if (page != 1) 'page': '$page',
        if (size != defaultPageSize) 'size': '$size',
        if (deleted != DeletedMode.active) 'deleted': deleted.name,
      };

  bool get hasFilters =>
      search.isNotEmpty || filters.isNotEmpty || deleted != DeletedMode.active;

  int get activeFilterCount =>
      filters.length + (deleted != DeletedMode.active ? 1 : 0);

  ListQuery clearFilters() => ListQuery(
        defaultSort: defaultSort,
        defaultAscending: defaultAscending,
        sortField: sortField,
        ascending: sortAscending,
        size: size,
      );

  ListQuery withFilter(String key, String? value) {
    final next = Map<String, String>.of(filters);
    if (value == null || value.isEmpty) {
      next.remove(key);
    } else {
      next[key] = value;
    }
    return copyWith(filters: next);
  }

  ListQuery copyWith({
    String? search,
    Map<String, String>? filters,
    String? sortField,
    bool? sortAscending,
    int? page,
    int? size,
    DeletedMode? deleted,
  }) =>
      ListQuery(
        defaultSort: defaultSort,
        defaultAscending: defaultAscending,
        search: search ?? this.search,
        filters: filters ?? this.filters,
        sortField: sortField ?? this.sortField,
        ascending: sortAscending ?? this.sortAscending,
        page: page ?? 1,
        size: size ?? this.size,
        deleted: deleted ?? this.deleted,
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ListQuery &&
          search == other.search &&
          _sameMap(filters, other.filters) &&
          sortField == other.sortField &&
          defaultSort == other.defaultSort &&
          sortAscending == other.sortAscending &&
          page == other.page &&
          size == other.size &&
          deleted == other.deleted;

  @override
  int get hashCode => Object.hash(
      search,
      Object.hashAllUnordered(
          filters.entries.map((e) => Object.hash(e.key, e.value))),
      sortField,
      defaultSort,
      sortAscending,
      page,
      size,
      deleted);

  static bool _sameMap(Map<String, String> a, Map<String, String> b) {
    if (a.length != b.length) return false;
    for (final e in a.entries) {
      if (b[e.key] != e.value) return false;
    }
    return true;
  }
}
