library;

const List<int> allowedPageSizes = [10, 25, 50];
const int defaultPageSize = 10;

int? parseIntParam(String? value) => value == null ? null : int.tryParse(value);

int parsePage(String? value) {
  final page = parseIntParam(value);
  return page == null || page < 1 ? 1 : page;
}

int parseSize(String? value) {
  final size = parseIntParam(value);
  return size != null && allowedPageSizes.contains(size)
      ? size
      : defaultPageSize;
}

bool parseBoolParam(String? value) => value == '1' || value == 'true';

({String field, bool ascending}) parseSort(
  String? value, {
  required Set<String> allowed,
  required String fallback,
  bool fallbackAscending = true,
}) {
  if (value == null || value.isEmpty) {
    return (field: fallback, ascending: fallbackAscending);
  }
  final parts = value.split(',');
  if (!allowed.contains(parts.first)) {
    return (field: fallback, ascending: fallbackAscending);
  }
  return (
    field: parts.first,
    ascending: parts.length < 2 || parts[1] != 'desc'
  );
}

String formatSort(String field, bool ascending) =>
    ascending ? field : '$field,desc';
