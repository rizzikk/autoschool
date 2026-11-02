import '../domain/entity_def.dart';
import '../domain/entities.dart';
import '../models/pb_record.dart';
import '../repositories/pb_filter.dart';
import '../repositories/record_repository.dart';

class RelationOptions {
  RelationOptions(this._repository,
      {this.ttl = const Duration(seconds: 30), DateTime Function()? clock})
      : _now = clock ?? DateTime.now;

  final RecordRepository _repository;
  final Duration ttl;
  final DateTime Function() _now;
  final Map<String, ({DateTime at, List<PbRecord> items})> _cache = {};

  String _key(RelationDef r) =>
      '${r.collection}|${toPbFilter(r.filter)}|${r.sort}';

  Future<List<PbRecord>> load(RelationDef relation) async {
    final key = _key(relation);
    final cached = _cache[key];
    if (cached != null && _now().difference(cached.at) < ttl) {
      return cached.items;
    }
    final def = entityDefs[relation.collection];
    final items = await _repository.listAll(
      relation.collection,
      where: relation.filter,
      sort: relation.sort,
    );
    final visible = def != null && def.softDelete
        ? items.where((r) => !r.deleted).toList()
        : items;
    _cache[key] = (at: _now(), items: visible);
    return visible;
  }

  String labelOf(RelationDef relation, PbRecord record) =>
      entityDefs[relation.collection]?.titleOf(record) ?? record.id;

  void invalidate() => _cache.clear();
}
