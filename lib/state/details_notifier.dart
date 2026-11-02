import 'package:flutter/foundation.dart';

import 'load_status.dart';

class DetailsNotifier<T> extends ChangeNotifier {
  DetailsNotifier(this._loader);

  final Future<T?> Function() _loader;

  T? _data;
  LoadStatus _status = LoadStatus.idle;
  String? _error;
  bool _disposed = false;

  T? get data => _data;
  LoadStatus get status => _status;
  String? get error => _error;
  bool get notFound => _status == LoadStatus.success && _data == null;

  Future<void> load() async {
    _status = LoadStatus.loading;
    _error = null;
    _notify();
    try {
      _data = await _loader();
      _status = LoadStatus.success;
    } catch (e) {
      _error = 'Не удалось загрузить запись: $e';
      _status = LoadStatus.error;
    }
    _notify();
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
