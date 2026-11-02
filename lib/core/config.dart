library;

import 'package:flutter/foundation.dart';

const _apiBaseUrlDefine = String.fromEnvironment('API_BASE_URL');

const apiBaseUrl = _apiBaseUrlDefine == '' ? '/api' : _apiBaseUrlDefine;

const maxReadAttempts = 3;

const tokenRefreshBefore = Duration(minutes: 10);

const apiLog = bool.fromEnvironment('API_LOG', defaultValue: kDebugMode);

class SessionPolicy {
  const SessionPolicy({
    required this.idleTimeout,
    required this.idleWarning,
    required this.maxDuration,
  });

  final Duration idleTimeout;

  final Duration idleWarning;

  final Duration maxDuration;

  static const fromEnvironment = SessionPolicy(
    idleTimeout: Duration(
        seconds: int.fromEnvironment('IDLE_TIMEOUT_SEC', defaultValue: 1800)),
    idleWarning: Duration(
        seconds: int.fromEnvironment('IDLE_WARNING_SEC', defaultValue: 60)),
    maxDuration: Duration(
        minutes: int.fromEnvironment('SESSION_MAX_MIN', defaultValue: 480)),
  );
}
