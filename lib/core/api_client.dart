import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_exceptions.dart';
import 'config.dart';
import 'connection.dart';
import 'session.dart';

Dio buildDio(
  ApiSession session, {
  String baseUrl = apiBaseUrl,
  Duration retryDelay = const Duration(milliseconds: 400),
  void Function(String line)? log,
  ConnectionNotifier? connection,
}) {
  final dio = Dio(
    BaseOptions(
      baseUrl: baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 15),
      headers: {'Content-Type': 'application/json'},
      validateStatus: (status) => status != null && status < 500,
    ),
  );
  dio.interceptors.add(ApiInterceptor(dio, session,
      retryDelay: retryDelay, log: log, connection: connection));
  return dio;
}

class ApiInterceptor extends Interceptor {
  ApiInterceptor(
    this._dio,
    this._session, {
    this.retryDelay = const Duration(milliseconds: 400),
    void Function(String line)? log,
    this.connection,
  }) : _logSink = log;

  final Dio _dio;
  final ApiSession _session;
  final Duration retryDelay;
  final void Function(String line)? _logSink;

  final ConnectionNotifier? connection;

  static bool isAuthPath(String path) => path.contains('/auth-');

  @override
  Future<void> onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final refresh = _session.refresh;
    if (refresh != null &&
        options.extra['skipAuth'] != true &&
        !isAuthPath(options.path) &&
        _session.isExpiringSoon(tokenRefreshBefore)) {
      _line('[AUTH] токен скоро истечёт — обновляю до запроса');
      await refresh();
    }
    final token = _session.accessToken;
    if (token != null && options.extra['skipAuth'] != true) {
      options.headers['Authorization'] = token;
      options.extra['token'] = token;
    } else {
      options.headers.remove('Authorization');
    }
    options.extra['startedAt'] ??= DateTime.now().millisecondsSinceEpoch;
    handler.next(options);
  }

  @override
  Future<void> onResponse(
      Response<dynamic> response, ResponseInterceptorHandler handler) async {
    final options = response.requestOptions;
    final status = response.statusCode ?? 0;
    _write(options, status);
    connection?.reportSuccess();
    if (status < 400) {
      handler.next(response);
      return;
    }

    final refresh = _session.refresh;
    if (status == 401 &&
        refresh != null &&
        !isAuthPath(options.path) &&
        options.extra['retried'] != true) {
      final current = _session.accessToken;
      final alreadyRefreshed =
          current != null && options.extra['token'] != current;
      if (!alreadyRefreshed) {
        _line(
            '[AUTH] 401 на ${options.method} ${options.path} — обновляю токен');
      }
      if (alreadyRefreshed || await refresh()) {
        options.extra['retried'] = true;
        options.extra['startedAt'] = DateTime.now().millisecondsSinceEpoch;
        _line(
            '[AUTH] токен обновлён, повторяю ${options.method} ${options.path}');
        try {
          handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          handler.reject(e, true);
        }
        return;
      }
      _line('[AUTH] обновить токен не удалось — выход из системы');
      handler.reject(
        DioException(
          requestOptions: options,
          response: response,
          type: DioExceptionType.badResponse,
          error: const UnauthorizedException(
              'Сессия истекла. Войдите в систему снова.'),
        ),
        true,
      );
      return;
    }

    handler.reject(
      DioException(
        requestOptions: options,
        response: response,
        type: DioExceptionType.badResponse,
        error: mapHttpError(status, response.data),
      ),
      true,
    );
  }

  @override
  Future<void> onError(
      DioException err, ErrorInterceptorHandler handler) async {
    final options = err.requestOptions;
    if (err.error is! ApiException) {
      _write(options, err.response?.statusCode, failure: err.type.name);
    }
    if (_isRetryable(err)) {
      final attempt = (options.extra['attempt'] as int? ?? 1);
      if (attempt < maxReadAttempts) {
        await Future<void>.delayed(retryDelay * (1 << (attempt - 1)));
        options.extra['attempt'] = attempt + 1;
        _line('[API] повтор ${attempt + 1}/$maxReadAttempts '
            '${options.method} ${options.uri}');
        try {
          handler.resolve(await _dio.fetch<dynamic>(options));
        } on DioException catch (e) {
          handler.next(e);
        }
        return;
      }
    }
    if (_isNetworkFailure(err)) connection?.reportFailure();
    handler.next(err);
  }

  bool _isNetworkFailure(DioException e) => switch (e.type) {
        DioExceptionType.connectionError ||
        DioExceptionType.connectionTimeout ||
        DioExceptionType.sendTimeout ||
        DioExceptionType.receiveTimeout =>
          true,
        _ => false,
      };

  bool _isRetryable(DioException e) {
    if (e.requestOptions.method.toUpperCase() != 'GET') return false;
    if (e.requestOptions.cancelToken?.isCancelled ?? false) return false;
    return switch (e.type) {
      DioExceptionType.connectionError ||
      DioExceptionType.connectionTimeout ||
      DioExceptionType.receiveTimeout =>
        true,
      _ => false,
    };
  }

  void _write(RequestOptions options, int? status, {String? failure}) {
    final started = options.extra['startedAt'] as int?;
    final ms = started == null
        ? ''
        : ' ${DateTime.now().millisecondsSinceEpoch - started} мс';
    _line('[API] ${options.method} ${options.uri} → '
        '${status ?? failure ?? '—'}$ms');
  }

  void _line(String text) {
    final sink = _logSink;
    if (sink != null) {
      sink(text);
    } else if (apiLog) {
      debugPrint(text);
    }
  }
}
