import 'conditions.dart';

String pbQuote(String s) =>
    "'${s.replaceAll(r'\', r'\\').replaceAll("'", r"\'")}'";

List<String> searchVariants(String text) {
  final t = text.trim();
  String cap(String w) =>
      w.isEmpty ? w : w[0].toUpperCase() + w.substring(1).toLowerCase();
  final variants = <String>{
    t,
    t.toLowerCase(),
    t.split(' ').map(cap).join(' '),
  };
  return variants.where((v) => v.isNotEmpty).toList();
}

String toPbFilter(Cond? cond) {
  if (cond == null) return '';
  return switch (cond) {
    Eq(:final field, :final value) =>
      '$field = ${value is String ? pbQuote(value) : value}',
    Has(:final field, :final value) => '$field.id ?= ${pbQuote(value)}',
    Like(:final field, :final text) => () {
        final parts = [
          for (final v in searchVariants(text)) '$field ~ ${pbQuote(v)}'
        ];
        return parts.length == 1 ? parts.first : '(${parts.join(' || ')})';
      }(),
    Gte(:final field, :final value) => '$field >= ${pbQuote(value)}',
    Lte(:final field, :final value) => '$field <= ${pbQuote(value)}',
    And(:final items) => _join(items, ' && '),
    Or(:final items) => _join(items, ' || '),
  };
}

String _join(List<Cond> items, String op) {
  final parts = [
    for (final c in items)
      if (toPbFilter(c).isNotEmpty) toPbFilter(c),
  ];
  if (parts.isEmpty) return '';
  if (parts.length == 1) return parts.first;
  return '(${parts.join(op)})';
}
