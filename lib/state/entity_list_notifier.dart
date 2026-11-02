import 'package:flutter/foundation.dart';

import '../core/api_exceptions.dart';
import '../domain/entity_def.dart';
import '../models/list_query.dart';
import '../models/page_result.dart';
import '../models/pb_record.dart';
import '../repositories/record_repository.dart';
import 'load_status.dart';

class BulkResult {
  const BulkResult({required this.done, required this.failed});

  final int done;

  final List<String> failed;

  bool get hasErrors => failed.isNotEmpty;
}

class EntityListNotifier extends ChangeNotifier {
  EntityListNotifier(
    this.def,
    this._repository, {
    ListQuery? query,
    this.canSeeDeleted = false,
    this.onChanged,
  }) : _query = query ?? def.queryFromParams(const {});

  final EntityDef def;
  final RecordRepository _repository;

  final bool canSeeDeleted;

  final VoidCallback? onChanged;

  ListQuery _query;
  PageResult<PbRecord> _result = PageResult<PbRecord>.empty();
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  final Set<String> _selected = {};
  int _request = 0;
  bool _disposed = false;

  ListQuery get query => _query;
  PageResult<PbRecord> get result => _result;
  LoadStatus get status => _status;
  String? get error => _error;
  Set<String> get selected => Set.unmodifiable(_selected);
  bool get hasSelection => _selected.isNotEmpty;

  Future<void> load() async {
    final request = ++_request;
    _status = LoadStatus.loading;
    _error = null;
    _notify();
    try {
      final result = await _repository.list(
        def.collection,
        page: _query.page,
        perPage: _query.size,
        where: def.buildCond(_query, canSeeDeleted: canSeeDeleted),
        sort: '${_query.sortAscending ? '' : '-'}${_query.sortField}',
        expand: def.expand,
      );
      if (request != _request) return;
      _result = result;
      _status = LoadStatus.success;
    } on CancelledException {
      return;
    } catch (e) {
      if (request != _request) return;
      _error = 'Не удалось загрузить список: $e';
      _status = LoadStatus.error;
    }
    _notify();
  }

  Future<void> applyQuery(ListQuery next) async {
    _query = next;
    _selected.clear();
    await load();
  }

  Future<void> syncWithQuery(ListQuery next) async {
    if (next == _query && _status != LoadStatus.idle) return;
    await applyQuery(next);
  }

  void toggleSelection(String id) {
    if (!_selected.remove(id)) _selected.add(id);
    _notify();
  }

  void setSelection(Iterable<String> ids, bool value) {
    if (value) {
      _selected.addAll(ids);
    } else {
      _selected.removeAll(ids);
    }
    _notify();
  }

  void clearSelection() {
    _selected.clear();
    _notify();
  }

  Future<void> softDelete(String id) async {
    await _repository.update(def.collection, id, {'deleted': true});
    _selected.remove(id);
    await _afterChange();
  }

  Future<void> restore(String id) async {
    await _repository.update(def.collection, id, {'deleted': false});
    _selected.remove(id);
    await _afterChange();
  }

  Future<void> hardDelete(String id) async {
    await _repository.delete(def.collection, id);
    _selected.remove(id);
    await _afterChange();
  }

  Future<void> runAction(RowAction action, PbRecord record) async {
    await action.run(_repository, record);
    await _afterChange();
  }

  Future<BulkResult> _bulk(Future<void> Function(String id) op) async {
    var done = 0;
    final failed = <String>[];
    for (final id in _selected.toList()) {
      try {
        await op(id);
        done++;
      } on ApiException catch (e) {
        failed.add(e.message);
      }
    }
    _selected.clear();
    await _afterChange();
    return BulkResult(done: done, failed: failed);
  }

  Future<BulkResult> softDeleteSelected() =>
      _bulk((id) => _repository.update(def.collection, id, {'deleted': true}));

  Future<BulkResult> restoreSelected() =>
      _bulk((id) => _repository.update(def.collection, id, {'deleted': false}));

  Future<BulkResult> hardDeleteSelected() =>
      _bulk((id) => _repository.delete(def.collection, id));

  Future<void> _afterChange() async {
    onChanged?.call();
    if (_status != LoadStatus.idle) await load();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
