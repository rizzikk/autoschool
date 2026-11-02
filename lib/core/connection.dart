import 'dart:async';

import 'package:flutter/foundation.dart';

class ConnectionNotifier extends ChangeNotifier {
  ConnectionNotifier({
    this.probe,
    this.interval = const Duration(seconds: 5),
  });

  final Future<bool> Function()? probe;
  final Duration interval;

  bool _offline = false;
  int _recoveries = 0;
  Timer? _timer;
  bool _probing = false;
  bool _disposed = false;

  bool get offline => _offline;

  int get recoveries => _recoveries;

  void reportFailure() {
    if (_offline || _disposed) return;
    _offline = true;
    _timer ??= Timer.periodic(interval, (_) => checkNow());
    notifyListeners();
  }

  void reportSuccess() {
    if (!_offline || _disposed) return;
    _offline = false;
    _recoveries++;
    _timer?.cancel();
    _timer = null;
    notifyListeners();
  }

  Future<void> checkNow() async {
    final probe = this.probe;
    if (probe == null || _probing || !_offline) return;
    _probing = true;
    try {
      if (await probe()) reportSuccess();
    } catch (_) {
    } finally {
      _probing = false;
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _timer?.cancel();
    super.dispose();
  }
}
